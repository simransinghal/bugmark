class ApplicationCommand
  include ActiveModel::Model

  # Application Command
  #
  # CQRS and EventSourcing for Rails
  #
  # This abstraction allows us to integrate more seamlessly with smart contracts
  # that run on the Ethereum Blockchain.  (referred to as the Ethereum API)
  #
  # In this scheme, the core data abstraction is the EventStore, an append-only
  # datastructure implemented as a PostgresQL Table.  Each record in the
  # EventStore is called an EventLine (see `models/event_line`)
  #
  # How it works:
  # - Commands operate like AR models (using `ActiveModel`)
  # - Commands are composed of sub-objects (standard Rails models)
  # - Commands can save an event to the EventStore
  # - Commands can be initialized from the EventStore
  # - Commands can generate `projections` (DDD parlance...)
  #
  # - use for forms - edit and create commands - anything that updates the DB
  #   - single-model updates
  #   - multi-model transactions
  # - creates event store
  #   - events are the ultimate source of truth
  #   - events are signed as in a merkle chain
  #   - events can be generated by commands OR come from Solidity contracts
  #   - events can have one or more projections
  #   - events can be replayed

  # - using commands from controllers
  #    `Command.new(params).project`
  # - using commands to replay events
  #    `Command.from_event(event).project`

  # form handling inspired by
  # http://blog.sundaycoding.com/blog/2016/01/08/contextual-validations-with-form-objects

  # ----- configuration methods

  # define an attr_accessor for each subobject
  # define a method `subobject_symbols` that returns the list of subobjects
  def self.attr_subobjects(*klas_list)
    attr_accessor(*klas_list)
    define_method 'subobject_symbols' do
      klas_list
    end
  end

  # delegate all fields of a subobject to the subobject
  def self.attr_delegate_fields(sym, opts = {})  #class_name
    klas_name = opts[:class_name] || sym
    klas    = klas_name.to_s.camelize.constantize
    getters = klas.attribute_names.map(&:to_sym)
    setters = klas.attribute_names.map { |x| "#{x}=".to_sym }
    delegate *getters, to: sym
    delegate *setters, to: sym
  end

  def self.attr_vdelegate(method, klas_sym)
    getter = method
    setter = "#{method}=".to_sym
    delegate getter, to: klas_sym
    delegate setter, to: klas_sym
  end

  # ----- template methods - override in subclass

  def add_event(key, event)
    raise "DUPLICATE KEY" if state[:events][key]
    state[:events][key] = event
    self.define_singleton_method("#{key.to_s}_event".to_sym) do
      state[:events][key]
    end
    self.define_singleton_method("#{key.to_s}_new".to_sym) do
      state[:events][key].new_object
    end
  end

  def events
    state[:events]
  end

  def self.from_event(_event)
    raise "from_event: override in subclass"
  end

  def transact_before_project
    # override in subclass
  end

  # ----- persistence methods

  def save
    raise "NOT ALLOWED - USE #project"
  end

  # synonym for project
  def cmd_cast
    if valid?
      ActiveRecord::Base.transaction do
        events.each do |key, event|
          varname = "@#{key.to_s}"
          self.define_singleton_method(key) { eval varname }
          object = event.ev_cast
          self.instance_variable_set varname, object
          raise ActiveRecord::Rollback unless object.valid?
        end
      end
      self
    else
      nil
    end
  end

  # pro*jekt* - create a projection - an aggregate data view
  def project
    valid?
    # puts errors.inspect unless valid?
    if valid?
      transact_before_project # perform a transaction, if any
      subs.each(&:save)       # save all subobjects
      self
    else
      false
    end
  end

  # ----- validation predicates

  # validations can live in the Command or the Sub-Object (or both!)
  def valid?
    if super && events.values.map(&:valid?).all?
      true
    else
      events.values.each do |obj|
        obj.valid?
        obj.errors.each do |field, error|
          errors.add(field, error)
        end
      end
      false
    end
  end

  # def valid?
  #   if subs.map(&:nil?).any?
  #     errors.add(:base, "missing sub-object (#{missing_subobjects.join(', ')})")
  #     return false
  #   end
  #   if super && subs.map(&:valid?).all?
  #     true
  #   else
  #     subs.each do |object|
  #       object.valid?                        # populate the subobject errors
  #       object.errors.each do |field, error| # transfer the error messages
  #         errors.add(field, error)
  #       end
  #     end
  #     false
  #   end

  def invalid?
    !valid?
  end

  def state
    @state ||= {}
    @state[:events] ||= {}
    @state
  end

  def state=(val)
    @state = val
  end

  private

  def cmd_uuid
    @cmd_uuid ||= SecureRandom.uuid
  end

  def cmd_type
    @cmd_type ||= self.class.name
  end

  def cmd_opts
    {"cmd_type" => cmd_type, "cmd_uuid" => cmd_uuid}
  end

  def save_event
    base = {cmd_type: cmd_type, cmd_id: cmd_id, user_ids: user_ids}
    data = {data: event_data}
    both = data.merge(base)
    Event.new(both).save

    if ! Rails.env.test? && File.exist?("/etc/influxdb/influxdb.conf")
      mname = "cmd." + self.class.name.gsub("::", "_")
      InfluxDB::Rails.client.write_point mname,
                                         tags:   influx_tags,
                                         values: influx_fields
    end
    self
  end

  def subobjects
    subobject_symbols.map { |el| self.send(el) }
  end

  alias_method :subs, :subobjects

  def missing_subobjects
    subobject_symbols.
      map {|el| [el, self.send(el)]}.
      select {|el| el.last.nil?}.
      map {|el| el.first}
  end

end
