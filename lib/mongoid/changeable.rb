# frozen_string_literal: true

module Mongoid

  # Defines behavior for dirty tracking.
  module Changeable
    extend ActiveSupport::Concern

    # Get the changed attributes for the document.
    #
    # @example Get the changed attributes.
    #   model.changed
    #
    # @return [ Array<String> ] The changed attributes.
    def changed
      changed_attributes.keys.select { |attr| attribute_change(attr) }
    end

    # Has the document changed?
    #
    # @example Has the document changed?
    #   model.changed?
    #
    # @return [ true | false ] If the document is changed.
    def changed?
      changes.values.any? { |val| val } || children_changed?
    end

    # Have any children (embedded documents) of this document changed?
    #
    # @note This intentionally only considers children and not descendants.
    #
    # @return [ true | false ] If any children have changed.
    def children_changed?
      _children.any?(&:changed?)
    end

    # Get the attribute changes.
    #
    # @example Get the attribute changes.
    #   model.changed_attributes
    #
    # @return [ Hash<String, Object> ] The attribute changes.
    def changed_attributes
      @changed_attributes ||= {}
    end

    # Get all the changes for the document.
    #
    # @example Get all the changes.
    #   model.changes
    #
    # @return [ Hash<String, Array<Object, Object> ] The changes.
    def changes
      changed.each_with_object({}) do |attr, changes|
        change = attribute_change(attr)
        changes[attr] = change if change
      end.with_indifferent_access
    end

    # Call this method after save, so the changes can be properly switched.
    #
    # This will unset the memoized children array, set new record flag to
    # false, set the document as validated, and move the dirty changes.
    #
    # @example Move the changes to previous.
    #   person.move_changes
    def move_changes
      @changes_before_last_save = @previous_changes
      @previous_changes = changes
      @attributes_before_last_save = @previous_attributes
      @previous_attributes = attributes.dup
      reset_atomic_updates!
      changed_attributes.clear
    end

    # Things that need to execute after a document has been persisted.
    #
    # @example Handle post persistence.
    #   document.post_persist
    def post_persist
      reset_persisted_descendants
      reset_attributes_before_type_cast
      move_changes
    end

    # Get the previous changes on the document.
    #
    # @example Get the previous changes.
    #   model.previous_changes
    #
    # @return [ Hash<String, Array<Object, Object> ] The previous changes.
    def previous_changes
      @previous_changes ||= {}
    end

    # Remove a change from the dirty attributes hash. Used by the single field
    # atomic updaters.
    #
    # @example Remove a flagged change.
    #   model.remove_change(:field)
    #
    # @param [ Symbol | String ] name The name of the field.
    def remove_change(name)
      changed_attributes.delete(name.to_s)
    end

    # Gets all the new values for each of the changed fields, to be passed to
    # a MongoDB $set modifier.
    #
    # @example Get the setters for the atomic updates.
    #   person = Person.new(:title => "Sir")
    #   person.title = "Madam"
    #   person.setters # returns { "title" => "Madam" }
    #
    # @return [ Hash ] A +Hash+ of atomic setters.
    def setters
      mods = {}
      changes.each_pair do |name, changes|
        next unless changes

        old, new = changes
        field = fields[name]
        key = atomic_attribute_name(name)
        if field&.resizable?
          field.add_atomic_changes(self, name, key, mods, new, old)
        else
          mods[key] = new unless atomic_unsets.include?(key)
        end
      end
      mods
    end

    # Returns the original value of an attribute before the last save.
    #
    # This method is useful in after callbacks to get the original value of
    #   an attribute before the save that triggered the callbacks to run.
    #
    # @param [ Symbol | String ] attr The name of the attribute.
    #
    # @return [ Object ] Value of the attribute before the last save.
    def attribute_before_last_save(attr)
      attr = database_field_name(attr)
      attributes_before_last_save[attr]
    end

    # Returns the change to an attribute during the last save.
    #
    # @param [ Symbol | String ] attr The name of the attribute.
    #
    # @return [ Array<Object> | nil ] If the attribute was changed, returns
    #   an array containing the original value and the saved value, otherwise nil.
    def saved_change_to_attribute(attr)
      attr = database_field_name(attr)
      previous_changes[attr]
    end

    # Returns whether this attribute changed during the last save.
    #
    # This method is useful in after callbacks, to see the change
    #   in an attribute during the save that triggered the callbacks to run.
    #
    # @param [ String ] attr The name of the attribute.
    # @param [ Object ] from The object the attribute was changed from (optional).
    # @param [ Object ] to The object the attribute was changed to (optional).
    #
    # @return [ true | false ] Whether the attribute has changed during the last save.
    def saved_change_to_attribute?(attr, from: Utils::PLACEHOLDER, to: Utils::PLACEHOLDER)
      changes = saved_change_to_attribute(attr)
      return false unless changes.is_a?(Array)
      return true if Utils.placeholder?(from) && Utils.placeholder?(to)
      return changes.first == from if Utils.placeholder?(to)
      return changes.last == to if Utils.placeholder?(from)

      changes.first == from && changes.last == to
    end

    # Returns whether this attribute change the next time we save.
    #
    # This method is useful in validations and before callbacks to determine
    #   if the next call to save will change a particular attribute.
    #
    # @param [ String ] attr The name of the attribute.
    # @param **kwargs The optional keyword arguments.
    #
    # @option **kwargs [ Object ] :from The object the attribute was changed from.
    # @option **kwargs [ Object ] :to The object the attribute was changed to.
    #
    # @return [ true | false ] Whether the attribute change the next time we save.
    def will_save_change_to_attribute?(attr, **kwargs)
      attribute_changed?(attr, **kwargs)
    end

    private

    # Get attributes of the document before the document was saved.
    #
    # @return [ Hash ] Previous attributes
    def previous_attributes
      @previous_attributes ||= {}
    end

    def changes_before_last_save
      @changes_before_last_save ||= {}
    end

    def attributes_before_last_save
      @attributes_before_last_save ||= {}
    end

    # Get the old and new value for the provided attribute.
    #
    # @example Get the attribute change.
    #   model.attribute_change("name")
    #
    # @param [ String ] attr The name of the attribute.
    #
    # @return [ Array<Object> ] The old and new values.
    def attribute_change(attr)
      attr = database_field_name(attr)
      [changed_attributes[attr], attributes[attr]] if attribute_changed?(attr)
    end

    # A class for representing the default value that an attribute was changed
    # from or to.
    #
    # @api private
    class Anything
      # `Anything` objects are always equal to everything. This simplifies
      # the logic for asking whether an attribute has changed or not. If the
      # `from` or `to` value is a `Anything` (because it was not
      # explicitly given), any comparison with it will suggest the value has
      # not changed.
      #
      # @param [ Object ] _other The object being compared with this object.
      #
      # @return [ true ] Always returns true.
      def ==(_other)
        true
      end
    end

    # A singleton object to represent an optional `to` or `from` value
    # that was not explicitly provided to #attribute_changed?
    ATTRIBUTE_UNCHANGED = Anything.new

    # Determine if a specific attribute has changed.
    #
    # @example Has the attribute changed?
    #   model.attribute_changed?("name")
    #
    # @param [ String ] attr The name of the attribute.
    # @param [ Object ] from The object the attribute was changed from (optional).
    # @param [ Object ] to The object the attribute was changed to (optional).
    #
    # @return [ true | false ] Whether the attribute has changed.
    def attribute_changed?(attr, from: ATTRIBUTE_UNCHANGED, to: ATTRIBUTE_UNCHANGED)
      attr = database_field_name(attr)
      changed_attributes.key?(attr) &&
        changed_attributes[attr] != attributes[attr] &&
        from == changed_attributes[attr] &&
        to == attributes[attr]
    end

    # Get whether or not the field has a different value from the default.
    #
    # @example Is the field different from the default?
    #   model.attribute_changed_from_default?
    #
    # @param [ String ] attr The name of the attribute.
    #
    # @return [ true | false ] If the attribute differs.
    def attribute_changed_from_default?(attr)
      return false unless (field = fields[attr])

      attributes[attr] != field.eval_default(self)
    end

    # Get the previous value for the attribute.
    #
    # @example Get the previous value.
    #   model.attribute_was("name")
    #
    # @param [ String ] attr The attribute name.
    def attribute_was(attr)
      attr = database_field_name(attr)
      attribute_changed?(attr) ? changed_attributes[attr] : attributes[attr]
    end

    # Get the previous attribute value that was changed
    # before the document was saved.
    #
    # It the document has not been saved yet, or was just loaded from database,
    # this method returns nil for all attributes.
    #
    # @param [ String ] attr The attribute name.
    #
    # @return [ Object | nil ] Attribute value before the document was saved,
    #   or nil if the document has not been saved yet.
    def attribute_previously_was(attr)
      attr = database_field_name(attr)
      if previous_changes.key?(attr)
        previous_changes[attr].first
      else
        previous_attributes[attr]
      end
    end

    # Flag an attribute as going to change.
    #
    # @example Flag the attribute.
    #   model.attribute_will_change!("name")
    #
    # @param [ String ] attr The name of the attribute.
    #
    # @return [ Object ] The old value.
    def attribute_will_change!(attr)
      return if changed_attributes.key?(attr)

      changed_attributes[attr] = read_raw_attribute(attr).__deep_copy__
    end

    # Set the attribute back to its old value.
    #
    # @example Reset the attribute.
    #   model.reset_attribute!("name")
    #
    # @param [ String ] attr The name of the attribute.
    #
    # @return [ Object ] The old value.
    def reset_attribute!(attr)
      attr = database_field_name(attr)
      attributes[attr] = changed_attributes.delete(attr) if attribute_changed?(attr)
    end

    def reset_attribute_to_default!(attr)
      attr = database_field_name(attr)
      if (field = fields[attr])
        __send__(:"#{attr}=", field.eval_default(self))
      else
        __send__(:"#{attr}=", nil)
      end
    end

    def reset_attributes_before_type_cast
      @attributes_before_type_cast = @attributes.dup
    end

    # Class-level methods for Changeable.
    module ClassMethods

      private

      # Generate all the dirty methods needed for the attribute.
      #
      # @example Generate the dirty methods.
      #   Model.create_dirty_methods("name", "name")
      #
      # @param [ String ] name The name of the field.
      # @param [ String ] meth The name of the accessor.
      #
      # @return [ Module ] The fields module.
      def create_dirty_methods(name, meth)
        create_dirty_change_accessor(name, meth)
        create_dirty_change_check(name, meth)
        create_dirty_change_flag(name, meth)
        create_dirty_default_change_check(name, meth)
        create_dirty_previous_value_accessor(name, meth)
        create_dirty_reset(name, meth)
        create_dirty_reset_to_default(name, meth)
        create_dirty_previously_changed?(name, meth)
        create_dirty_previous_change(name, meth)
      end

      # Creates the dirty change accessor.
      #
      # @example Create the accessor.
      #   Model.create_dirty_change_accessor("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_change_accessor(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_change") do
            attribute_change(name)
          end
        end
      end

      # Creates the dirty change check.
      #
      # @example Create the check.
      #   Model.create_dirty_change_check("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_change_check(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_changed?") do |**kwargs|
            attribute_changed?(name, **kwargs)
          end
          re_define_method("will_save_change_to_#{meth}?") do |**kwargs|
            will_save_change_to_attribute?(name, **kwargs)
          end
        end
      end

      # Creates the dirty default change check.
      #
      # @example Create the check.
      #   Model.create_dirty_default_change_check("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_default_change_check(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_changed_from_default?") do
            attribute_changed_from_default?(name)
          end
        end
      end

      # Creates the dirty change previous value accessors.
      #
      # @example Create the accessor.
      #   Model.create_dirty_previous_value_accessor("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_previous_value_accessor(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_was") do
            attribute_was(name)
          end
          re_define_method("#{meth}_previously_was") do
            attribute_previously_was(name)
          end
          re_define_method("#{meth}_before_last_save") do
            attribute_before_last_save(name)
          end
          re_define_method("saved_change_to_#{meth}") do
            saved_change_to_attribute(name)
          end
          re_define_method("saved_change_to_#{meth}?") do |**kwargs|
            saved_change_to_attribute?(name, **kwargs)
          end
        end
      end

      # Creates the dirty change flag.
      #
      # @example Create the flag.
      #   Model.create_dirty_change_flag("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_change_flag(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_will_change!") do
            attribute_will_change!(name)
          end
        end
      end

      # Creates the dirty change reset.
      #
      # @example Create the reset.
      #   Model.create_dirty_reset("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_reset(name, meth)
        generated_methods.module_eval do
          re_define_method("reset_#{meth}!") do
            reset_attribute!(name)
          end
        end
      end

      # Creates the dirty change reset to default.
      #
      # @example Create the reset.
      #   Model.create_dirty_reset_to_default("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_reset_to_default(name, meth)
        generated_methods.module_eval do
          re_define_method("reset_#{meth}_to_default!") do
            reset_attribute_to_default!(name)
          end
        end
      end

      # Creates the dirty change check.
      #
      # @example Create the dirty change check.
      #   Model.create_dirty_previously_changed?("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_previously_changed?(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_previously_changed?") do
            previous_changes.key?(name)
          end
        end
      end

      # Creates the dirty change accessor.
      #
      # @example Create the dirty change accessor.
      #   Model.create_dirty_previous_change("name", "alias")
      #
      # @param [ String ] name The attribute name.
      # @param [ String ] meth The name of the accessor.
      def create_dirty_previous_change(name, meth)
        generated_methods.module_eval do
          re_define_method("#{meth}_previous_change") do
            previous_changes[name]
          end
        end
      end
    end
  end
end
