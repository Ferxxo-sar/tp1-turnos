module Api
  module V1
    class StylistsController < BaseController
      def index
        render json: Stylist.alphabetical.with_attached_photo.map { |stylist| stylist_json(stylist) }
      end

      def show
        render json: stylist_json(Stylist.find(params[:id]))
      end

      # GET /api/v1/stylists/:id/availability?date=2026-10-01
      def availability
        stylist = Stylist.find(params[:id])
        date = Date.iso8601(params[:date].to_s)
        slots = stylist.available_slots(date)

        render json: { date: date.iso8601, slots: slots.map { |slot| slot.strftime("%H:%M") } }
      rescue Date::Error
        render json: { error: "Fecha inválida, usar formato AAAA-MM-DD" }, status: :bad_request
      end
    end
  end
end
