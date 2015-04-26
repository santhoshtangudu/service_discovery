class Order < ActiveRecord::Base
  belongs_to :address
  belongs_to :service
  has_many :order_logs
  validates_presence_of :service, :address

  state_machine :status, :initial => :created do
    event :complete do
      transition :created => :completed
    end

    store_audit_trail to: OrderLog
  end

  def self.find_orders(user_id)
    orders = Order.joins(:address).where('addresses.user_id' => user_id)
    orders.collect(&:fields_for_find_orders)
  end

  def fields_for_find_orders
    {order_id: id, slot_start_time: slot_start_time,
     status: status, service_name: service.name}
  end

  def fields_for_get_order
    as_json.symbolize_keys.tap do |fields|
      fields.except!(:updated_at, :address_id, :service_id)
      fields[:order_id] = fields.delete(:id)
      fields[:service_name] = service.name
      fields[:address] = address.as_json(except: [:updated_at, :created_at])
    end
  end
end
