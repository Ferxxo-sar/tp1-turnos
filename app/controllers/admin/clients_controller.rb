module Admin
  class ClientsController < BaseController
    def index
      @clients = Client.order(:name)
      if params[:q].present?
        query = "%#{Client.sanitize_sql_like(params[:q])}%"
        @clients = @clients.where("name LIKE :q OR email LIKE :q", q: query)
      end
    end

    def show
      @client = Client.find(params[:id])
      @appointments = @client.appointments.with_details.order(scheduled_at: :desc)
    end
  end
end
