class ImportService
  def initialize(import)
    @import = import
    @map = import.map
    @errors = []
  end

  def process
    rows = parse_file
    @import.update!(total_rows: rows.size, processed_rows: 0, success_count: 0, error_count: 0)

    mapping = (@import.column_mapping || {}).symbolize_keys

    rows.each_with_index do |row, index|
      process_row(row, mapping, index + 2) # +2 for 1-based + header row
    end

    @import.update!(
      status: "completed",
      error_log: @errors.presence
    )
  rescue StandardError => e
    @import.update!(status: "failed", error_log: [ { row: 0, message: e.message } ])
    raise ImportError.new(e.message, context: { import_id: @import.id })
  end

  private

  def parse_file
    @import.file.blob.open do |tempfile|
      ext = File.extname(@import.file_name).downcase
      case ext
      when ".csv"
        CSV.read(tempfile.path, headers: true).map(&:to_h)
      when ".xlsx", ".xls"
        spreadsheet = Roo::Spreadsheet.open(tempfile.path, extension: ext.delete("."))
        headers = spreadsheet.row(1)
        (2..spreadsheet.last_row).map do |i|
          Hash[headers.zip(spreadsheet.row(i))]
        end
      else
        raise UnsupportedFileFormatError.new("Unsupported file format: #{ext}", context: { import_id: @import.id, extension: ext })
      end
    end
  end

  def process_row(row, mapping, row_number)
    attrs = {}

    # Extract lat/lng
    if mapping[:lat].present? && mapping[:lng].present?
      lat = row[mapping[:lat]]&.to_f
      lng = row[mapping[:lng]]&.to_f
      attrs[:lat] = lat
      attrs[:lng] = lng
    elsif mapping[:address].present?
      # Address-only: place at 0,0 and enqueue geocoding
      attrs[:lat] = 0.0
      attrs[:lng] = 0.0
      attrs[:description] = row[mapping[:address]]
    else
      record_error(row_number, "No lat/lng or address mapping")
      return
    end

    attrs[:title] = row[mapping[:title]] if mapping[:title].present?
    attrs[:description] = row[mapping[:description]] if mapping[:description].present?

    if mapping[:color].present?
      color = normalize_color(row[mapping[:color]])
      attrs[:color] = color if color
    end

    # Handle group — group color wins over per-row color
    if mapping[:group].present? && row[mapping[:group]].present?
      group_name = row[mapping[:group]].to_s.strip
      group = find_or_create_group(group_name)
      attrs[:marker_group_id] = group.id
      attrs[:color] = group.color
    end

    marker = @map.markers.build(attrs)
    if marker.save
      @import.increment!(:success_count)

      # Enqueue geocoding if address-only
      if mapping[:address].present? && mapping[:lat].blank?
        api_key = @map.user.api_keys.first&.google_maps_key
        GeocodeJob.perform_later(marker.id, api_key) if api_key
      end
    else
      record_error(row_number, marker.errors.full_messages.join(", "))
    end

    @import.increment!(:processed_rows)
  rescue StandardError => e
    record_error(row_number, e.message)
    @import.increment!(:processed_rows)
  end

  def find_or_create_group(name)
    @groups_cache ||= {}
    @groups_cache[name] ||= begin
      group = @map.marker_groups.find_by(name: name)
      group || @map.marker_groups.create!(name: name, color: random_color)
    end
  end

  def random_color
    @used_colors ||= []
    palette = %w[
      #EF4444 #F97316 #F59E0B #22C55E #14B8A6
      #3B82F6 #8B5CF6 #EC4899 #6366F1 #06B6D4
    ]
    available = palette - @used_colors
    available = palette if available.empty?
    color = available.sample
    @used_colors << color
    color
  end

  def normalize_color(value)
    return nil if value.blank?
    color = value.to_s.strip
    return color if color.match?(/\A#[0-9A-Fa-f]{6}\z/)
    "##{color}" if color.match?(/\A[0-9A-Fa-f]{6}\z/)
  end

  def record_error(row_number, message)
    @errors << { row: row_number, message: message }
    @import.increment!(:error_count)
  end
end
