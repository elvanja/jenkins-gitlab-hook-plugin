require 'spec_helper'

module GitlabWebHook
  describe RequestDetails do
    context "with validation" do
      it "is valid when repository url is present" do
        expect(subject).to receive(:repository_url).and_return("http://repo.url")
        expect(subject.is_valid?).to be_true
      end

      it "is not valid when repository url is missing" do
        [nil, "", "  \n  "].each do |repository_url|
          expect(subject).to receive(:repository_url).and_return(repository_url)
          expect(subject.is_valid?).to be_false
        end
      end
    end

    context "with repository url" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with repository name" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with repository homepage" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with full branch name" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with branch" do
      it "extracts branch name from payload" do
        expect(subject).to receive(:full_branch_reference).and_return("refs/heads/master")
        expect(subject.branch).to eq("master")
      end

      it "returns empty branch name when no branch reference data found" do
        expect(subject).to receive(:full_branch_reference).and_return(nil)
        expect(subject.branch).to eq("")
      end

      it "makes branch safe" do
        expect(subject).to receive(:full_branch_reference).and_return("refs/heads/feature/cool")
        expect(subject.safe_branch).to eq("feature_cool")
      end

      it "returns nil when no payload present" do
        expect(subject).to receive(:full_branch_reference).and_return(nil)
        expect(subject.branch).to eq("")
      end

      it "removes refs and heads from result" do
        refs = ["ref", "refs"]
        heads = ["head", "heads"]
        refs.product(heads).each do |combination|
          expect(subject).to receive(:full_branch_reference).and_return("#{combination.join("/")}/master")
          expect(subject.branch).to eq("master")
        end
      end

      it "detects non refs and non heads" do
        ["refref", "headhead"].each do |ref|
          expect(subject).to receive(:full_branch_reference).and_return(ref)
          expect(subject.branch).to eq(ref)
        end
      end

      it "returns branch name" do
        expect(subject).to receive(:full_branch_reference).and_return("refs/heads/master")
        expect(subject.branch).to eq("master")
      end

      it "respects nested branches" do
        expect(subject).to receive(:full_branch_reference).and_return("refs/heads/feature/new_hot_feature")
        expect(subject.branch).to eq("feature/new_hot_feature")
      end
    end

    context "with delete branch commit" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with commits" do
      it "expects to implemented in concrete implementation" do
        expect { subject.repository_url }.to raise_exception(NameError)
      end
    end

    context "with commits count" do
      it "returns commits size" do
        expect(subject).to receive(:commits).at_least(:once).and_return([double, double, double])
        expect(subject.commits_count).to eq(3)
      end

      it "defaults to 0 when no commits present" do
        expect(subject).to receive(:commits).and_return(nil)
        expect(subject.commits_count).to eq(0)
      end
    end

    context "with payload" do
      it "expects to implemented in concrete implementation" do
        expect { subject.payload }.to raise_exception(NameError)
      end
    end
  end
end
