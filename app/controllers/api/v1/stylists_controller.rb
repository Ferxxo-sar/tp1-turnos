module Api
  module V1
    class StylistsController < BaseController
      def index
        stylists = Stylist.alphabetical.with_attached_photo
        if params[:q].present?
          term = "%#{Stylist.sanitize_sql_like(params[:q].strip)}%"
          stylists = stylists.where("name LIKE :term OR specialty LIKE :term", term: term)
        end
        render json: stylists.map { |stylist| stylist_json(stylist) }
      end

      def show
        render json: stylist_json(Stylist.find(params[:id]))
      end

      # GET /api/v1/stylists/:id/availability?date=2026-10-01&service_ids[]=1
      # Con service_ids solo devuelve los horarios donde entra la duración total.
      def availability
        stylist = Stylist.find(params[:id])
        date = parse_date(params[:date])
        return render_error("Fecha inválida, usar formato AAAA-MM-DD", :bad_request) unless date

        duration = [ Service.where(id: Array(params[:service_ids])).sum(:duration_minutes), Stylist::SLOT_MINUTES ].max
        render json: slots_json(date, duration, stylist.available_slots(date, duration: duration))
      end
    end
  end
end
