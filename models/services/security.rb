include Java

java_import Java.hudson.security.ACL
java_import Java.org.acegisecurity.context.SecurityContextHolder

module GitlabWebHook
    class Security
        def self.impersonate(acl = ACL::ANONYMOUS)
            securityContext = ACL.impersonate(acl)
            begin
                yield
            ensure
                SecurityContextHolder.setContext(securityContext)
            end
        end
    end
end
