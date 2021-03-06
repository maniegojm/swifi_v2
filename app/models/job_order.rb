class JobOrder < ActiveRecord::Base
  self.per_page = 100

  # Mixins - Start
  include Bitfields
  # Mixins - End

  # Associations - Start
  belongs_to :client
  has_one :bill, dependent: :destroy
  has_one :expense, dependent: :destroy

  accepts_nested_attributes_for :bill, :client
  # Associations - End

  # Constants - Start
  DEFAULT_VALUES = {
    sea: true,
    import: true
  }

  ATTR_ACCESSOR_DEFAULT_VALUES = {
    select_client: true
  }

  NUMBER_CODE_LENGTH = 4

  MODE_OF_SHIPMENT = 0
  SERVICE_TYPE     = 1
  SERVICES         = 2

  FIELD_NAMES = [
    :mode_of_shipment,
    :service_type,
    :services
  ]

  MODE_OF_SHIPMENT_SEA = 1
  MODE_OF_SHIPMENT_AIR = 2
  SERVICE_TYPE_IMPORT  = 1
  SERVICE_TYPE_EXPORT  = 2
  SERVICES_BROKERAGE   = 1
  SERVICES_FORWARDING  = 2
  SERVICES_BF          = 3

  FIELD_VALUES = [
    { MODE_OF_SHIPMENT_SEA => "sea",     MODE_OF_SHIPMENT_AIR => "air" },
    { SERVICE_TYPE_IMPORT => "import",   SERVICE_TYPE_EXPORT => "export" },
    { SERVICES_BROKERAGE => "brokerage", SERVICES_FORWARDING => "forwarding" }
  ]

  VALID_VALUES = [
    [MODE_OF_SHIPMENT_SEA, MODE_OF_SHIPMENT_AIR],
    [SERVICE_TYPE_IMPORT, SERVICE_TYPE_EXPORT],
    [SERVICES_BROKERAGE, SERVICES_FORWARDING, SERVICES_BF]
  ]

  ACCESSIBLE_ATTRIBUTES = [
    :client_id,
    :mode_of_shipment,
    :service_type,
    :brokerage,
    :forwarding,
    :select_client
  ]

  ATTR_ACCESSORS = [
    :select_client
  ]
  # Constants - End

  # Bitfields - Start
  bitfield FIELD_NAMES[MODE_OF_SHIPMENT], FIELD_VALUES[MODE_OF_SHIPMENT]
  bitfield FIELD_NAMES[SERVICE_TYPE], FIELD_VALUES[SERVICE_TYPE]
  bitfield FIELD_NAMES[SERVICES], FIELD_VALUES[SERVICES]
  # Bitfields - End

  # Validations - Start
  validates FIELD_NAMES[MODE_OF_SHIPMENT], inclusion: { in: VALID_VALUES[MODE_OF_SHIPMENT] }
  validates FIELD_NAMES[SERVICE_TYPE], inclusion: { in: VALID_VALUES[SERVICE_TYPE] }
  validates FIELD_NAMES[SERVICES], inclusion: { in: VALID_VALUES[SERVICES] }
  validates :client_id, presence: true

  validate :origin_should_be_editable
  # Validations - End

  # Scopes - Start
  scope :for_year,      lambda {|year| where('EXTRACT(YEAR FROM created_at) = ?', year) }
  scope :for_this_year, -> { for_year(Date.today.year) }
  # Scopes - End

  # attr_accessor - Start
  attr_accessor *ATTR_ACCESSORS
  # attr_accessor - End

  # Callbacks - Start
  after_create do |job_order|
    generate_number
  end

  before_create :build_expense

  after_initialize do
    set_default_values
  end
  # Callbacks - End

  # Class Methods
  class << self
    def mode_of_shipments
      for_dropdown(JobOrder::FIELD_VALUES[JobOrder::MODE_OF_SHIPMENT])
    end

    def service_types
      for_dropdown(JobOrder::FIELD_VALUES[JobOrder::SERVICE_TYPE])
    end

    def services
      for_dropdown(JobOrder::FIELD_VALUES[JobOrder::SERVICES])
    end

    # def parse_code_number(code_str)
    #   # services, number,  = code_str.split('-')
    #   code_str.split('-')[1].to_i
    # end
  end
  # Overrides - Start
  # def services=(services)
  #   if services.kind_of?(Array)
  #     # try ["", 1].select(&:present?) vs ["", 1].compact
  #     services = services.select(&:present?).map(&:to_i).inject(&:+) || 0
  #   end
  #   super(services)
  # end
  # Overrides - End

  def set_default_values
    # set_new_record_default_values
    set_attr_accessor_default_values
  end

  def set_new_record_default_values
    self.assign_attributes DEFAULT_VALUES if new_record?
  end

  def set_attr_accessor_default_values
    self.assign_attributes ATTR_ACCESSOR_DEFAULT_VALUES
  end

  def latest_number
    JobOrder.for_this_year.maximum(:number) || 0
  end

  def next_jo_number
    latest_number + 1
  end

  def generate_number
    self.number = next_jo_number
    save!
  end

  def client_name
    client.name
  end

  def client_name_display
    client.name_display
  end

  def mode_of_shipment_display
    FIELD_VALUES[MODE_OF_SHIPMENT][mode_of_shipment].humanize
  end

  def service_type_display
    FIELD_VALUES[SERVICE_TYPE][service_type].humanize
  end

  def services_list(to_bit = false)
    list = FIELD_VALUES[SERVICES].select{|bitvalue, name| !(bitvalue & services).zero? }
    (to_bit && list.keys) || list.values
  end

  def services_display
    services_list.map{|v| v.humanize}.join(", ")
  end

  def created_at_code
    created_at.strftime('%m-%y')
  end

  def number_code
    number_length = number.to_s.length
    multiply_by   = NUMBER_CODE_LENGTH - number_length
    multiply_by   = multiply_by > 0 ? multiply_by : 0
    "#{'0' * multiply_by}#{number}"
  end

  def shipment_mode_code
    mode_of_shipment_display[0]
  end

  def service_type_code
    service_type_display[0]
  end

  def services_code
    services_list.map{ |name| name[0].upcase }.join
  end
  # TODO: service_code method name
  def service_code
    "#{shipment_mode_code}#{service_type_code}#{services_code}"
  end

  def code
    "#{service_code}-#{number_code}-#{created_at_code}"
  end

  def created_at_display
    created_at.strftime("%D")
  end

  def container_number_is_editable?
    new_record? || sea
  end

  def shipper_name_display
    bill.shipper_name_display
  end

  def consignee_name_display
    bill.consignee_name_display
  end

  def has_expense_line_items?
    expense.expense_line_items.present?
  end

  private

    def self.for_dropdown(job_order_field_values)
      job_order_field_values.map{|value, name| [name.humanize, value]}
    end

    def origin_should_be_editable
      if bill.container_number_changed? && !container_number_is_editable?
        errors.add(:origin, "is not editable because mode of shipment is not by \"Sea\".")
      end
    end
end
