# Adnaneh Elasticsearch

## How do I install these formulae?

`brew install adnaneh/elasticsearch/<formula>`

Or `brew tap adnaneh/elasticsearch` and then `brew install <formula>`.

After this run the following commands to add bundled java to the firewall, otherwise requests to allow connections will keep popping every time elasticsearch is executed. Do this before adding elasticsearch manually or through the pop up modal as this will not work and will conflict with the instructions below.

```
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
/usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/Cellar/elasticsearch/8.4.3/libexec/jdk.app/Contents/Home/bin/java
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
