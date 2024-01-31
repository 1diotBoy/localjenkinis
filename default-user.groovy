import jenkins.model.*
import hudson.security.*
import org.csanchez.jenkins.plugins.kubernetes.*

def env = System.getenv()
def jenkins = Jenkins.getInstance()

if(!(jenkins.getSecurityRealm() instanceof HudsonPrivateSecurityRealm))
    jenkins.setSecurityRealm(new HudsonPrivateSecurityRealm(false))

if(!(jenkins.getAuthorizationStrategy() instanceof GlobalMatrixAuthorizationStrategy))
    jenkins.setAuthorizationStrategy(new GlobalMatrixAuthorizationStrategy())

def user = jenkins.getSecurityRealm().createAccount(env.JENKINS_USER, env.JENKINS_PASS)
user.save()

jenkins.getAuthorizationStrategy().add(Jenkins.ADMINISTER, env.JENKINS_USER)

jenkins.save()

def localCloud = new KubernetesCloud(
    'powerk8s',
    null,
    '',
    'jenkins',
    'http://jenkins.jenkins.svc.cluster.local:8080',
    '10', 0, 0, 5
)
localCloud.setSkipTlsVerify(true)
localCloud.setJenkinsTunnel('jenkins-agent.jenkins.svc.cluster.local:50000')
jenkins.instance.clouds.add(localCloud)
jenkins.save()


