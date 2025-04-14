# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Verse::Schema::Coalescer do
  subject { Verse::Schema::Coalescer }
  context "#transform" do
    context String do
      it "coalesces to a string" do
        expect(subject.transform("foo", String)).to eq("foo")
        expect(subject.transform(1, String)).to eq("1")
        expect(subject.transform(1.0, String)).to eq("1.0")
        expect { subject.transform(nil, String) }.to raise_error(Verse::Schema::Coalescer::Error)
      end
    end

    context Integer do
      it "coalesces to an integer" do
        expect(subject.transform("1", Integer)).to eq(1)
        expect(subject.transform(1, Integer)).to eq(1)
        expect(subject.transform(1.0, Integer)).to eq(1)

        expect { subject.transform(nil, Integer) }.to raise_error Verse::Schema::Coalescer::Error
        expect { subject.transform("", Integer) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end

    context Float do
      it "coalesces to a float" do
        expect(subject.transform("1", Float)).to eq(1.0)
        expect(subject.transform(1, Float)).to eq(1.0)
        expect(subject.transform(1.0, Float)).to eq(1.0)

        expect { subject.transform(nil, Float) }.to raise_error Verse::Schema::Coalescer::Error
        expect { subject.transform("", Float) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end

    context Symbol do
      it "coalesces to a symbol" do
        expect(subject.transform("1", Symbol)).to eq(:'1')
        expect(subject.transform(1, Symbol)).to eq(:'1')
        expect(subject.transform(1.0, Symbol)).to eq(:'1.0')
        expect { subject.transform(nil, Symbol) }.to raise_error Verse::Schema::Coalescer::Error
        expect { subject.transform("", Symbol) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end

    context Time do
      it "coalesces to a time" do
        expect(subject.transform("2019-01-01", Time)).to eq(Time.parse("2019-01-01"))
        expect(subject.transform(Time.parse("2019-01-01"), Time)).to eq(Time.parse("2019-01-01"))
        expect { subject.transform(nil, Time) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end

    context Date do
      it "coalesces to a date" do
        expect(subject.transform("2019-01-01", Date)).to eq(Date.parse("2019-01-01"))
        expect(subject.transform(Date.parse("2019-01-01"), Date)).to eq(Date.parse("2019-01-01"))
        expect { subject.transform(nil, Date) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end

    context TrueClass do
      it "coalesces to a true class" do
        expect(subject.transform("true", TrueClass)).to eq(true)
        expect(subject.transform(1, TrueClass)).to eq(true)
        expect(subject.transform(1.0, TrueClass)).to eq(true)
        expect(subject.transform(true, TrueClass)).to eq(true)

        expect(subject.transform(false, TrueClass)).to eq(false)
        expect(subject.transform("false", TrueClass)).to eq(false)
        expect(subject.transform(0, TrueClass)).to eq(false)
        expect(subject.transform(0.0, TrueClass)).to eq(false)

        expect { subject.transform(nil, TrueClass) }.to raise_error Verse::Schema::Coalescer::Error
      end
    end
  end
end
