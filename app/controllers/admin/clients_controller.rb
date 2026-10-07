module Admin
  class ClientsController < BaseController
    before_action :set_client, only: %i[show edit update destroy]

    def index
      clients = Client.order(:name)
      if params[:q].present?
        query = "%#{Client.sanitize_sql_like(params[:q].strip)}%"
        clients = clients.where("name LIKE :q OR email LIKE :q OR phone LIKE :q", q: query)
      end
      @clients = paginate(clients)
      @appointment_counts = Appointment.where(client_id: @clients.map(&:id)).where.not(status: "cancelled").group(:client_id).count
    end

    def show
      @appointments = paginate(@client.appointments.with_details.order(scheduled_at: :desc), per: 15)
      @stats = {
        total: @client.appointments.count,
        completed: @client.appointments.where(status: "completed").count,
        cancelled: @client.appointments.where(status: "cancelled").count,
        spent: AppointmentService.joins(:appointment)
                                 .where(appointments: { client_id: @client.id, status: "completed" })
                                 .sum(:price_at_booking),
        next: @client.appointments.upcoming.chronological.first,
        last_visit: @client.appointments.where(status: "completed").maximum(:scheduled_at)
      }
    end

    def new
      @client = Client.new
    end

    # Alta desde el mostrador: si no se carga contraseña se genera una al azar;
    # el cliente puede registrarse después o pedir que se la cambien.
    def create
      @client = Client.new(client_params)
      @client.password = SecureRandom.base58(16) if @client.password.blank?

      if @client.save
        redirect_to admin_client_path(@client), notice: "Cliente creado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @client.update(client_params)
        redirect_to admin_client_path(@client), notice: "Cliente actualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @client.appointments.upcoming.exists?
        redirect_to admin_client_path(@client), alert: "El cliente tiene turnos próximos. Cancelalos antes de eliminarlo."
      else
        @client.destroy!
        redirect_to admin_clients_path, notice: "Cliente eliminado."
      end
    end

    private

    def set_client
      @client = Client.find(params[:id])
    end

    def client_params
      params.expect(client: %i[name email phone password])
    end
  end
end
