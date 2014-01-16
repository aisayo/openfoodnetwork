require 'spec_helper'

feature "As a consumer I want to shop with a distributor", js: true do
  include AuthenticationWorkflow
  include WebHelper

  describe "Viewing a distributor" do
    let(:distributor) { create(:distributor_enterprise) }

    before do #temporarily using the old way to select distributor
      create_enterprise_group_for distributor
      visit "/"
      click_link distributor.name
    end
    it "shows a distributor" do
      visit shop_path
      page.should have_text distributor.name
    end

    describe "With products in order cycles" do
      let(:supplier) { create(:supplier_enterprise) }
      let(:product) { create(:product, supplier: supplier) }
      let(:order_cycle) { create(:order_cycle, distributors: [distributor], coordinator: create(:distributor_enterprise)) }

      before do
        exchange = Exchange.find(order_cycle.exchanges.to_enterprises(distributor).outgoing.first.id) 
        exchange.variants << product.master
      end

      it "shows the suppliers/producers for a distributor" do
        visit shop_path
        click_link "Our Producers"
        page.should have_content supplier.name 
      end

    end


    describe "selecting an order cycle" do
      it "selects an order cycle if only one is open" do
        # create order cycle
        oc1 = create(:simple_order_cycle, distributors: [distributor])
        exchange = Exchange.find(oc1.exchanges.to_enterprises(distributor).outgoing.first.id) 
        exchange.update_attribute :pickup_time, "turtles" 
        
        visit shop_path
        page.should have_selector "option[selected]", text: 'turtles'
      end

      describe "with multiple order cycles" do
        let(:oc1) {create(:simple_order_cycle, distributors: [distributor])} 
        let(:oc2) {create(:simple_order_cycle, distributors: [distributor])} 
        before do
          exchange = Exchange.find(oc1.exchanges.to_enterprises(distributor).outgoing.first.id) 
          exchange.update_attribute :pickup_time, "frogs" 
          exchange = Exchange.find(oc2.exchanges.to_enterprises(distributor).outgoing.first.id) 
          exchange.update_attribute :pickup_time, "turtles" 
        end

        it "shows a select with all order cycles" do
          visit shop_path
          page.should have_selector "option", text: 'frogs'
          page.should have_selector "option", text: 'turtles'
        end

        describe "with products in our order cycle" do
          let(:product) { create(:simple_product) }
          before do
            exchange = Exchange.find(oc1.exchanges.to_enterprises(distributor).outgoing.first.id) 
            exchange.variants << product.master
            visit shop_path
          end
          
          it "allows us to select an order cycle" do
            select "frogs", :from => "order_cycle_id"
            Spree::Order.last.order_cycle.should == nil
            page.should have_selector "products"
            page.should have_content "Orders close #{oc1.orders_close_at.strftime('%A %m')}"
            Spree::Order.last.order_cycle.should == oc1
          end

          it "doesn't show products before an order cycle is selected" do
            page.should_not have_content product.name 
          end

          it "shows products when an order cycle has been selected" do
            select "frogs", :from => "order_cycle_id"
            page.should have_content product.name 
          end

          it "updates the orders close note when order cycle is changed" do
            select "frogs", :from => "order_cycle_id"
            page.should have_content "Orders close #{oc1.orders_close_at.strftime('%A %m')}"
          end
        end
      end

      describe "with products with variants" do
        let(:oc) { create(:simple_order_cycle, distributors: [distributor]) }
        let(:product) { create(:simple_product) }
        let(:variant) { create(:variant, product: product) }

        before do
          build_and_select_order_cycle
        end

        it "should not show quantity field for product with variants" do
          page.should_not have_selector("#variants_#{product.master.id}", visible: true)
        end
      end

      describe "adding products to cart" do
        let(:oc) { create(:simple_order_cycle, distributors: [distributor]) }
        let(:product) { create(:simple_product) }
        let(:variant) { create(:variant, product: product) }
        before do
          build_and_select_order_cycle
        end
        it "should let us add products to our cart" do
          fill_in "variants[#{variant.id}]", with: "1"
          first("form.custom > input.button.right").click
          current_path.should == "/cart" 
          page.should have_content product.name
        end
      end

      context "when no order cycles are available" do
        it "tells us orders are closed" do
          visit shop_path
          page.should have_content "Orders are currently closed for this hub"
        end
        it "shows the last order cycle" do
          oc1 = create(:simple_order_cycle, distributors: [distributor], orders_close_at: 10.days.ago)
          visit shop_path
          page.should have_content "The last cycle closed 10 days ago"
        end
        it "shows the next order cycle" do
          oc1 = create(:simple_order_cycle, distributors: [distributor], orders_open_at: 10.days.from_now)
          visit shop_path
          page.should have_content "The next cycle opens in 10 days"
        end
      end
    end
  end
end

def build_and_select_order_cycle
  exchange = Exchange.find(oc.exchanges.to_enterprises(distributor).outgoing.first.id) 
  exchange.update_attribute :pickup_time, "frogs" 
  exchange.variants << product.master
  exchange.variants << variant 
  visit shop_path
  select "frogs", :from => "order_cycle_id"
end
