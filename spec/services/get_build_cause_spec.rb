require 'spec_helper'

module GitlabWebHook
  describe GetBuildCause do
    let(:details) { double(RequestDetails, :payload => nil, :repository_url => "http://localhost/peronospora") }

    context "with repository details" do
      it "contains repository host" do
        cause = subject.with(details)
        expect(cause.shortDescription).to match("localhost")
      end
    end

    context "with no payload" do
      it "contains default message" do
        cause = subject.with(details)
        expect(cause.shortDescription).to match("no payload available")
      end
    end

    context "with payload" do
      it "contains payload details" do
        details.stub(:payload).and_return(true)
        details.stub(:full_branch_reference).and_return("master")
        details.stub(:commits_count).and_return(1)
        details.stub(:commits).and_return([double(Commit, :url => "http://localhost/peronospora/commits/123456", :message => "fix")])

        cause = subject.with(details)
        expect(cause.shortDescription).not_to match("no payload available")
        expect(cause.shortDescription).to match("commits/123456")
      end
    end

    context "when validating" do
      it "requires details" do
        expect { subject.with(nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end