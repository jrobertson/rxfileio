Gem::Specification.new do |s|
  s.name = 'rxfileio'
  s.version = '0.2.3'
  s.summary = 'Features remote file operations using the DFS protocol and more.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/rxfileio.rb']
  s.add_runtime_dependency('rxfreadwrite', '~> 0.2', '>=0.2.5')
  s.add_runtime_dependency('drb_fileclient', '~> 0.8', '>=0.8.0')
  s.add_runtime_dependency('mymedia_ftp', '~> 0.3', '>=0.3.3')
  s.signing_key = '../privatekeys/rxfileio.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/rxfileio'
end
