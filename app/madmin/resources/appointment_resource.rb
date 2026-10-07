class AppointmentResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :created_at, form: false, index: false
  attribute :notes
  attribute :scheduled_at, index: true
  attribute :status, index: true
  attribute :updated_at, form: false

  # Associations
  attribute :client, index: true
  attribute :stylist, index: true
  attribute :appointment_services
  attribute :services

  # Add scopes to easily filter records
  # scope :published

  # Add actions to the resource's show page
  # Pass collection: true to also render it in each row on the index page
  # member_action do |record|
  #   link_to "Do Something", some_path
  # end

  # Add actions to the resource's index page
  # collection_action do
  #   link_to "Bulk Import", bulk_import_path, class: "btn btn-secondary"
  # end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = "##{record.id} · #{record.client.name} · #{I18n.l(record.scheduled_at, format: :short)}"

  # Customize the default sort column and direction.
  # def self.default_sort_column = "created_at"
  #
  # def self.default_sort_direction = "desc"
end
