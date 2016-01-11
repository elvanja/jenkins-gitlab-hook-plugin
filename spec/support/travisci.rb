
module Autologin

  module_function

  def enable
    set_known_hosts
    create_key
  end

  private

  # Adds localhost to known_hosts file
  def self.set_known_hosts
    fd = File.open "#{ENV['HOME']}/.ssh/known_hosts", 'a+'
    begin
      begin
        line = fd.readline
      end until line.start_with? 'localhost'
    rescue EOFError => e
      puts "Adding localhost public key"
      ecdsa = File.read '/etc/ssh/ssh_host_ecdsa_key.pub'
      fd.puts "localhost #{ecdsa}"
    end
    fd.close
  end

  # Create key and enable autologin
  def self.create_key
    ssh_dir = File.join ENV['HOME'], '.ssh'
    id_rsa = File.join ssh_dir, 'id_rsa'
    unless File.exists? id_rsa
      puts "Creating ssh keypair"
     `ssh-keygen -f "#{id_rsa}" -P ""`
    end
    File.open(File.join(ssh_dir, 'authorized_keys'), 'w') do |outfd|
      pubkey = File.read File.join(ssh_dir, 'id_rsa.pub')
      outfd.write pubkey
    end
  end

end
