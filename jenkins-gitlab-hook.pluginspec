Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "jenkins-gitlab-hook"
  plugin.display_name = "Jenkins Gitlab Hook Plugin"
  plugin.version = '0.0.2'
  plugin.description = 'Enables Gitlab web hooks to be used to trigger SMC polling on Gitlab projects'

  # You should create a wiki-page for your plugin when you publish it, see
  # https://wiki.jenkins-ci.org/display/JENKINS/Hosting+Plugins#HostingPlugins-AddingaWikipage
  # This line makes sure it's listed in your POM.
  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/Jenkins+Gitlab+Hook+Plugin'

  # The first argument is your user name for jenkins-ci.org.
  plugin.developed_by "elvanja", "Vanja Radovanovic <elvanja@gmail.com>"

  # This specifies where your code is hosted.
  # Alternatives include:
  #  :github => 'myuser/jenkins-gitlab-hook-plugin' (without myuser it defaults to jenkinsci)
  #  :git => 'git://repo.or.cz/jenkins-gitlab-hook-plugin.git'
  #  :svn => 'https://svn.jenkins-ci.org/trunk/hudson/plugins/jenkins-gitlab-hook-plugin'
  plugin.uses_repository :github => "jenkins-gitlab-hook-plugin"

  # This is a required dependency for every ruby plugin.
  plugin.depends_on 'ruby-runtime', '0.10'

  # This is a sample dependency for a Jenkins plugin, 'git'.
  #plugin.depends_on 'git', '1.1.11'
end
