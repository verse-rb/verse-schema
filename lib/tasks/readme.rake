# frozen_string_literal: true

require_relative "readme_doc_extractor"

namespace :readme do
  desc "Generate README.md from specs"
  task :generate do
    # Ensure RSpec is loaded
    require "rspec"

    # Load the application
    require_relative "../../lib/verse/schema"

    # Load the spec environment
    require_relative "../../spec/spec_helper"

    # Load all the spec files
    Dir["#{File.dirname(__FILE__)}/../../spec/**/*_spec.rb"].each { |f| require f }

    # Extract documentation from specs
    doc_extractor = ReadmeDocExtractor.new
    examples = doc_extractor.extract_from_specs

    # Debug output
    puts "Found #{examples.keys.size} sections:"
    examples.each do |section, section_examples|
      puts "  - #{section}: #{section_examples.size} examples"
    end

    # Generate README from template
    template_path = File.join(File.dirname(__FILE__), "../../templates/README.md.erb")

    # Generate the README
    readme_content = doc_extractor.generate_readme(template_path)

    # Write to README.md
    File.write(File.join(File.dirname(__FILE__), "../../README.md"), readme_content)

    puts "README.md generated successfully"
  end

  desc "Generate a chapter of the README from specs"
  task :generate_chapter, [:chapter_name] do |_t, args|
    chapter_name = args[:chapter_name]

    if chapter_name.nil? || chapter_name.empty?
      puts "Please provide a chapter name"
      puts "Usage: rake readme:generate_chapter[chapter_name]"
      exit 1
    end

    # Ensure RSpec is loaded
    require "rspec"

    # Load the application
    require_relative "../../lib/verse/schema"

    # Load the spec environment
    require_relative "../../spec/spec_helper"

    # Load all the spec files
    Dir["#{File.dirname(__FILE__)}/../../spec/**/*_spec.rb"].each { |f| require f }

    # Extract documentation from specs
    doc_extractor = ReadmeDocExtractor.new
    examples = doc_extractor.extract_from_specs

    # Check if the chapter exists
    unless examples.key?(chapter_name)
      puts "Chapter '#{chapter_name}' not found"
      puts "Available chapters: #{examples.keys.join(", ")}"
      exit 1
    end

    # Generate chapter content
    chapter_content = <<~MARKDOWN
      ### #{chapter_name}

      #{examples[chapter_name].map { |example| "```ruby\n#{example}\n```" }.join("\n\n")}
    MARKDOWN

    # Write to a temporary file
    temp_file = File.join(File.dirname(__FILE__), "../../tmp/#{chapter_name.downcase.gsub(/\s+/, "_")}.md")

    # Create the tmp directory if it doesn't exist
    tmp_dir = File.dirname(temp_file)
    FileUtils.mkdir_p(tmp_dir) unless File.directory?(tmp_dir)

    File.write(temp_file, chapter_content)

    puts "Chapter '#{chapter_name}' generated successfully at #{temp_file}"
    puts "You can now copy this content to your README.md file"
  end
end
