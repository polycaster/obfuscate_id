module ObfuscateId
  def obfuscate_id(options = {})
    require 'hashids'

    extend ClassMethods
    include InstanceMethods

    cattr_accessor :obfuscate_id_spin
    self.obfuscate_id_spin = (options[:spin] || obfuscate_id_default_spin)

    cattr_accessor :obfuscate_id_hashid_alphabet
    self.obfuscate_id_hashid_alphabet = (options[:alphabet] || Hashids::DEFAULT_ALPHABET)

    cattr_accessor :obfuscate_id_hashid_min
    self.obfuscate_id_hashid_min = (options[:min] || 0)
  end

  def self.hide(id, spin, minimum_length, alphabet)
    Hashids.new(spin.to_s, minimum_length, alphabet).encode(id)
  end

  def self.show(id, spin, minimum_length, alphabet)
    Hashids.new(spin.to_s, minimum_length, alphabet).decode(id).first
  end

  module ClassMethods
    def find_by_obfuscated_id(*args)
      scope = args.slice!(0)
      options = args.slice!(0) || {}
      if has_obfuscated_id? && !options[:no_obfuscated_id]
        if scope.is_a?(Array)
          scope.map! { |a| deobfuscate_id(a).to_i }
        else
          scope = deobfuscate_id(scope)
        end
      end
      find(scope)
    end

    def has_obfuscated_id?
      true
    end

    def deobfuscate_id(obfuscated_id)
      ObfuscateId.show(obfuscated_id,
        self.obfuscate_id_spin,
        self.obfuscate_id_hashid_min,
        self.obfuscate_id_hashid_alphabet)
    end

    # Generate a default spin from the Model name
    # This makes it easy to drop obfuscate_id onto any model
    # and produce different obfuscated ids for different models
    def obfuscate_id_default_spin
      alphabet = Array("a".."z")
      number = name.split("").collect do |char|
        alphabet.index(char)
      end

      number.shift(12).join.to_i
    end
  end

  module InstanceMethods
    def to_param
      ObfuscateId.hide(self.id,
        self.class.obfuscate_id_spin,
        self.obfuscate_id_hashid_min,
        self.obfuscate_id_hashid_alphabet)
    end

    # Override ActiveRecord::Persistence#reload
    # passing in an options flag with { no_obfuscated_id: true }
    def reload(options = nil)
      options = (options || {}).merge(no_obfuscated_id: true)

      clear_aggregation_cache
      clear_association_cache

      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock(options[:lock]).find_by_obfuscated_id(id, options) }
        else
          self.class.unscoped { self.class.find_by_obfuscated_id(id, options) }
        end

      @attributes = fresh_object.instance_variable_get('@attributes')
      @new_record = false
      self
    end

    def deobfuscate_id(obfuscated_id)
      self.class.deobfuscate_id(obfuscated_id)
    end
  end
end

ActiveRecord::Base.extend ObfuscateId
