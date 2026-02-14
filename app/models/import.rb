class Import < ApplicationRecord
  STATUSES = %w[pending mapping processing completed failed].freeze

  belongs_to :map
  has_one_attached :file

  validates :file_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  serialize :error_log, coder: JSON
  serialize :column_mapping, coder: JSON

  def progress_percentage
    return 0 if total_rows.zero?
    ((processed_rows.to_f / total_rows) * 100).round
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def processing?
    status == "processing"
  end
end
