require 'spec_helper'

module GitlabWebHook
  describe Settings do
    context "whether automatic project creation is enabled" do
      it "defines it" do
        expect(Settings).to respond_to(:automatic_project_creation?)
      end

      it "has default" do
        expect(Settings.automatic_project_creation?).to be(false)
      end
    end

    context "with master branch identificator" do
      it "defines it" do
        expect(Settings).to respond_to(:master_branch)
      end

      it "has default" do
        expect(Settings.master_branch).to eq("master")
      end
    end

    context "whether to use master project name" do
      it "defines it" do
        expect(Settings).to respond_to(:use_master_project_name?)
      end

      it "has default" do
        expect(Settings.use_master_project_name?).to eq(false)
      end
    end

    context "with automatically created project description" do
      it "defines it" do
        expect(Settings).to respond_to(:description)
      end

      it "has default" do
        expect(Settings.description).to eq("automatically created by Gitlab Web Hook plugin")
      end
    end

    context "with any branch search pattern" do
      it "defines it" do
        expect(Settings).to respond_to(:any_branch_pattern)
      end

      it "has default" do
        expect(Settings.any_branch_pattern).to eq("**")
      end
    end
  end
end
