module Spree
  module Wombat
    module Handler
      class UpdateShipmentHandler < Base

        def process

          shipment_hsh = @payload[:shipment]

          order_number = shipment_hsh.delete(:order_id)
          shipment_number = shipment_hsh.delete(:id)

          shipment = Spree::Shipment.find_by_number(shipment_number)
          return response("Can't find shipment #{shipment_number}", 500) unless shipment

          target_state = shipment_hsh.delete(:status)

          shipment_attributes = {
            tracking: shipment_hsh[:tracking]
          }

          # check if a state transition is required, and search for correct event to fire
          transition = nil

          if shipment.state != target_state
            unless transition = shipment.state_transitions.detect { |trans| trans.to == target_state }
              return response("Cannot transition shipment from current state: '#{shipment.state}' to requested state: '#{target_state}', no transition found.", 500)
            end
          end

          #update attributes
          shipment.update(shipment_attributes)

          #fire state transition
          if transition
            shipment.fire_state_event(transition.event)
          end

          shipment.save!

          # Ensure Order shipment state and totals are updated.
          # Note: we call update_shipment_state separately from update in case order is not in completed.
          shipment.order.updater.update_shipment_state
          shipment.order.updater.update

          return response("Updated shipment #{shipment_number}", 200, Base.wombat_objects_for(shipment))
        end

      end
    end
  end
end
