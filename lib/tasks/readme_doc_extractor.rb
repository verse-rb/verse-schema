# frozen_string_literal: true

require "rspec"
require "erb"

class ReadmeDocExtractor
  attr_reader :chapters

  def initialize
    @chapters = {}
  end

  # Extract documentation from specs tagged with :readme
  def extract_from_specs
    # Load RSpec configuration
    RSpec.configure do |config|
      config.formatter = "progress"
      config.color = false
    end

    # Find all specs tagged with :readme
    readme_specs = find_readme_specs

    # Run the specs and collect examples
    run_specs(readme_specs)

    # Return the chapters organized hierarchically
    @chapters
  end

  # Generate README content from the extracted chapters and a template
  def generate_readme(template_path)
    # Load the template
    template = File.read(template_path)

    # Create a binding with the chapters
    chapters_binding = binding

    # Render the template with ERB
    ERB.new(template, trim_mode: "-").result(chapters_binding)
  end

  private

  # Find all specs tagged with :readme
  def find_readme_specs
    puts "Looking for specs tagged with :readme"

    # Load all spec files
    puts "Loading spec files..."
    Dir["#{File.dirname(__FILE__)}/../../spec/**/*_spec.rb"].each do |f|
      puts "  - Loading #{f}"
      require f
    end

    # Find specs tagged with :readme
    readme_specs = RSpec.world.example_groups.select do |group|
      group.metadata[:readme]
    end

    puts "Found #{readme_specs.size} readme specs"
    readme_specs.each do |group|
      puts "  - #{group.description}"
    end

    # Return the specs
    readme_specs.map { |group| [group, group.examples] }.to_h
  end

  # Run the specs and collect examples into chapters and sections
  def run_specs(readme_specs)
    readme_specs.each_key do |group|
      collect_chapter_from_group(group)
    end
  end

  # Collect chapter and its sections from a group
  def collect_chapter_from_group(group)
    chapter_name = group.description.to_s
    puts "Collecting chapter: #{chapter_name}"
    return unless group.metadata[:readme]

    @chapters[chapter_name] = {}

    # Process child groups (sections)
    puts "  Chapter has #{group.children.size} sections (children)"
    group.children.each do |child|
      section_name = child.description.to_s
      puts "  - Processing section: #{section_name}, readme_section: #{child.metadata[:readme_section]}"
      next unless child.metadata[:readme_section]

      @chapters[chapter_name][section_name] ||= []

      # Process examples in this section
      puts "    Section has #{child.examples.size} examples"
      child.examples.each do |example|
        puts "    - Example: #{example.description}"
        next if example.metadata[:skip]

        # Extract code from the example
        code = extract_code_from_example(example)
        if code
          puts "      Extracted code (#{code.lines.count} lines)"
          @chapters[chapter_name][section_name] << code
        else
          puts "      No code extracted"
        end
      end
    end
  end

   # Extract code from an example
  def extract_code_from_example(example)
    # Get the example block directly using instance_variable_get
    example_block = example.instance_variable_get(:@example_block)
    return nil unless example_block

    # Get the source code of the block
    block_source = example_block.source
    return nil unless block_source

    # Clean up the code (only handle indentation)
    clean_code(block_source)
  end

  # Clean up the code - only handle indentation
  def clean_code(code)
    # Remove trailing whitespace from each line
    code = code.gsub(/[ \t]+$/, "")

    # Fix indentation by processing each line individually
    lines = code.lines
    non_empty_lines = lines.reject { |line| line.strip.empty? }
    min_indent = non_empty_lines.map { |line| line[/^ */].size }.min || 0

    # Remove rubocop comments
    lines = lines.reject { |line| line =~ /# *rubocop:.*/ }
    # Remove lines with :nodoc:
    lines = lines.reject { |line| line =~ /# *:nodoc:/ }

    # Remove the minimum indentation from each line
    if min_indent > 0
      lines = lines.map do |line|
        if line.strip.empty?
          line
        else
          line.sub(/^ {#{min_indent}}/, "")
        end
      end
      code = lines.join
    end

    # Ensure the code ends with a newline
    code += "\n" unless code.end_with?("\n")

    code
  end
end
