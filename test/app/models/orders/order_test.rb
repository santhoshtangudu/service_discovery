require File.expand_path(File.dirname(__FILE__) + '/../../../test_config.rb')

class OrderTest < ActiveSupport::TestCase
  context "Order Model" do
    should 'construct new instance' do
      @order = Order.new
      assert_not_nil @order
    end
  end

  context 'Find Orders' do
    setup do
      @user1 = FactoryGirl.create(:user)
      @user2 = FactoryGirl.create(:user)
      @address1 = FactoryGirl.create(:address, user: @user1)
      @address2 = FactoryGirl.create(:address, user: @user2)
      @order1 = FactoryGirl.create(:order, address: @address1, slot_start_time: '2015-04-04 10:00:00',
                                   service: FactoryGirl.create(:service, name: 'service1'))
      @order2 = FactoryGirl.create(:order, address: @address1, slot_start_time: '2015-04-05 10:00:00', actual_end_time: Time.now,
                                   service: FactoryGirl.create(:service, name: 'service2'), status: 'completed')
      @order3 = FactoryGirl.create(:order, address: @address2)
    end

    should 'find orders and return expected fields' do
      actual_orders = Order.find_orders(@user1.id)
      expected_orders =
          [{order_id: @order1.id, slot_start_time: @order1.slot_start_time, status: 'created', service_name: 'service1'},
           {order_id: @order2.id, slot_start_time: @order2.slot_start_time, status: 'completed', service_name: 'service2'}]
      assert_equal expected_orders, actual_orders
    end
  end

  context 'Fields for get order' do
    should 'return expected fields for get order' do
      order = FactoryGirl.create(:order)
      actual_fields = order.fields_for_get_order
      assert_order_fields(order, actual_fields.except(:address))
      assert_address_fields(order.address, actual_fields[:address])
    end

    def assert_order_fields(order, actual_fields)
      order_attrs = order.attributes.symbolize_keys
      expected_fields = order_attrs.slice(:actual_end_time, :actual_start_time, :created_at, :slot_start_time, :status, :total_price)
      expected_fields.merge!(order_id: order.id, service_name: order.service.name).as_json
      assert_equal expected_fields, actual_fields
    end

    def assert_address_fields(address, actual_fields)
      expected_fields = address.attributes.except!('created_at', 'updated_at')
      assert_equal expected_fields, actual_fields
    end
  end

  context "Transition to started" do
    should "not be allowed if actual start time is not present" do
      order = FactoryGirl.create(:order, status: 'confirmed')
      assert_raises(StateMachine::InvalidTransition) do
        order.start!
      end
    end

    should "be allowed if actual start time is present" do
      order = FactoryGirl.create(:order, status: 'confirmed', actual_start_time: Time.now)
      assert_nothing_raised do
        order.start!
      end
    end
  end

  context "Transition to completed" do
    should "not be allowed if actual end time is not present" do
      order = FactoryGirl.create(:order, status: 'started', actual_start_time: Time.now)
      assert_raises(StateMachine::InvalidTransition) do
        order.complete!
      end
    end

    should "be allowed if actual start time is present" do
      order = FactoryGirl.create(:order, status: 'started', actual_start_time: Time.now, actual_end_time: Time.now)
      assert_nothing_raised do
        order.complete!
      end
    end
  end

  context "Set End Time and Price" do
    should "set end time and call pricer" do
      order = FactoryGirl.create(:order)
      Pricer.any_instance.expects(:calculate_price)
      order.set_end_time_and_price("2014-04-04 18:32:08")
      assert_equal "2014-04-04 18:32:08", order.actual_end_time.to_s(:db)
    end
  end
end
