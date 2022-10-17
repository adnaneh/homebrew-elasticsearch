class Elasticsearch < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.4.3-darwin-x86_64.tar.gz"
  version "8.4.3"
  sha256 "73aca4820add4a81c93d57a392f0c7275f8a86d926f180ac32cbd9bba1fce27a"
  conflicts_with "elasticsearch"

  # elasticsearch will be relicensed before v7.11.
  # https://www.elastic.co/blog/licensing-change

  depends_on "gradle@6" => :build
  depends_on "openjdk"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    os = OS.kernel_name.downcase
    # system "gradle", ":distribution:archives:oss-no-jdk-#{os}-tar:assemble"

      # Extract the package to the tar directory
      # system "tar", "--strip-components=1", "-xf",
      #   Dir["../distribution/archives/oss-no-jdk-#{os}-tar/build/distributions/elasticsearch-oss-*.tar.gz"].first

      # Install into package directory
      libexec.install "bin", "lib", "modules", "jdk.app"
      system "codesign", "-f", "--deep", "-s", "-", "#{libexec}/modules/x-pack-ml/platform/darwin-x86_64/controller.app"
      system "find", "#{libexec}/jdk.app/Contents/Home/bin", "-type", "f", "-exec", "codesign", "-f", "-s", "-", "{}", ";"

      # Set up Elasticsearch for local development:
      inreplace "config/elasticsearch.yml" do |s|
        # 1. Give the cluster a unique name
        s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")

        # 2. Configure paths
        s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/elasticsearch/")
        s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
      end

      inreplace "config/jvm.options", %r{logs/gc.log}, "#{var}/log/elasticsearch/gc.log"

      # Move config files into etc
      (etc/"elasticsearch").install Dir["config/*"]
    

    inreplace libexec/"bin/elasticsearch-env",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/elasticsearch\"; fi"

    bin.install libexec/"bin/elasticsearch",
                libexec/"bin/elasticsearch-keystore",
                libexec/"bin/elasticsearch-plugin",
                libexec/"bin/elasticsearch-shard"
    bin.env_script_all_files libexec/"bin", Language::Java.overridable_java_home_env
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/elasticsearch").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config" unless (libexec/"config").exist?
    (var/"elasticsearch/plugins").mkpath
    ln_s var/"elasticsearch/plugins", libexec/"plugins" unless (libexec/"plugins").exist?
    # fix test not being able to create keystore because of sandbox permissions
    system bin/"elasticsearch-keystore", "create" unless (etc/"elasticsearch/elasticsearch.keystore").exist?
  end

  def caveats
    <<~EOS
      Data:    #{var}/lib/elasticsearch/
      Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
      Plugins: #{var}/elasticsearch/plugins/
      Config:  #{etc}/elasticsearch/
    EOS
  end

  plist_options manual: "elasticsearch"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <false/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/elasticsearch</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/elasticsearch.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/elasticsearch.log</string>
        </dict>
      </plist>
    EOS
  end

  test do
    port = free_port
    (testpath/"data").mkdir
    (testpath/"logs").mkdir
    fork do
      exec bin/"elasticsearch", "-Ehttp.port=#{port}",
                                "-Epath.data=#{testpath}/data",
                                "-Epath.logs=#{testpath}/logs"
    end
    sleep 20
    output = shell_output("curl -s -XGET localhost:#{port}/")
    assert_equal "oss", JSON.parse(output)["version"]["build_flavor"]

    system "#{bin}/elasticsearch-plugin", "list"
  end
end
