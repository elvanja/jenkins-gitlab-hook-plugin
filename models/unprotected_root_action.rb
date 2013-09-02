module Jenkins
  module Model
    class UnprotectedRootAction
      include Jenkins::Model::Action
    end

    class UnprotectedRootActionProxy
      include ActionProxy
      include Java.hudson.model.UnprotectedRootAction
      proxy_for Jenkins::Model::UnprotectedRootAction
    end
  end
end
