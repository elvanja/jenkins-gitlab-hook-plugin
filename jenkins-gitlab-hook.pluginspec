Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "gitlab-hook"
  plugin.display_name = "Gitlab Hook Plugin"
  plugin.version = '0.2.7'
  plugin.description = 'Enables Gitlab web hooks to be used to trigger SMC polling on Gitlab projects'

  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/Gitlab+Hook+Plugin'
  plugin.developed_by "elvanja", "Vanja Radovanovic <elvanja@gmail.com>"
  plugin.uses_repository :github => "elvanja/jenkins-gitlab-hook-plugin"

  plugin.depends_on 'ruby-runtime', '0.11'
  plugin.depends_on 'git', '1.1.26'
end
