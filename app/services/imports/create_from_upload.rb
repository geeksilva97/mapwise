class Imports::CreateFromUpload
  def self.call(map, file)
    new(map, file).call
  end

  def initialize(map, file)
    @map = map
    @file = file
  end

  def call
    import = @map.imports.build(
      file_name: @file.original_filename,
      status: "mapping"
    )
    import.file.attach(@file)

    if import.save
      headers = Imports::ParseHeaders.call(import)
      { import: import, headers: headers }
    else
      { error: import.errors }
    end
  end
end
