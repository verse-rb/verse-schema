#Troubleshoot performances
require "bundler"

Bundler.require

require "verse/schema"

# Good real life example struggling in term of perfs
ShiftEntrySchema = Verse::Schema.define do
  field :from, Time
  field :to, Time

  field? :project_id, [Integer, NilClass]

  field :productive, TrueClass
  field :billable, TrueClass

  field(:details, String).default("")

  rule :from, "from should be less than to" do |object|
    next object[:from] <= object[:to]
  end

  rule :project_id, "Project id must be set if productive set to true" do |object|
    if object[:productive] && object[:project_id].nil?
      next false
    end

    true
  end

  rule :project_id, "Billable must have a project_id" do |object|
    if object[:billable] && object[:project_id].nil?
      next false
    end

    true
  end
end

ShiftEntry = ShiftEntrySchema.dataclass do
  def duration
    to - from
  end
end

require "ruby-prof"

def run_profiler

  RubyProf.start

  100_000.times do
    ShiftEntry.new({"to"=>"2024-10-16 12:00:00",
      "from"=>"2024-10-16 04:00:00",
      "details"=>"Worked on the project",
      "billable"=>true,
      "productive"=>true,
      "project_id"=>1
    })
  end

  # Stop profiling
  result = RubyProf.stop

  # Print a flat report to the console (or choose other report formats)
  printer = RubyProf::GraphPrinter.new(result)
  printer.print(STDOUT, min_percent: 0.1)  # Adjust min_percent to filter results

  time = Time.now.to_f
  10_000.times do
    ShiftEntry.new({"to"=>"2024-10-16 12:00:00",
      "from"=>"2024-10-16 04:00:00",
      "details"=>"Worked on the project",
      "billable"=>true,
      "productive"=>true,
      "project_id"=>1
    })
  end
  puts "Time: #{1000 * (Time.now.to_f - time)}ms"
end

run_profiler