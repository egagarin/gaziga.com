require 'fileutils'

module Jekyll

    class AliasFile < StaticFile
        require 'set'

        def destination(dest)
            File.join(dest, @dir)
        end

        def modified?
            return false
        end

        def write(dest)
            return true
        end
    end

    class AliasGenerator < Generator
        priority :lowest
        @@patterns = {
            "^(.+)/tags(.+)" => "^(.+)/tag(.+)"
        }

        def generate(site)
            @site = site
            process_posts
            process_pages
        end

        def process_posts
            @site.posts.each do |post|
                generate_aliases(post.url, [*post.data['alias']], post)
            end
        end

        def process_pages
            @site.pages.each do |page|
                generate_aliases(page.destination('').gsub(/index\.(html|htm)$/, ''), [*page.data['alias']], page)
            end
        end

        def generate_aliases(destination_path, aliases, page)
            aliases ||= Array.new

            aliases << destination_path.gsub(/-/, ' ')
            aliases << destination_path.gsub(/-/, '_')
            aliases << destination_path.gsub(" ", '-')

            aliases = aliases.compact.reject{|a| a == destination_path}
            aliases.each do |alias_path|
                generate_alias(destination_path, alias_path)
            end
        end

        def generate_alias(destination_path, alias_path)
            alias_dir = File.join(@site.dest, alias_path)
            FileUtils.mkdir_p(alias_dir)
            alias_index = File.join(alias_dir, "index.html")
            File.open(File.join(alias_dir, "index.html"), 'w') do |file|
                file.write(alias_template(destination_path))
            end

            alias_index = alias_index.gsub(@site.dest, '')

            (2..alias_index.split('/').size).step(1) do |sections|
                @site.static_files << Jekyll::AliasFile.new(@site, @site.dest, alias_index.split('/')[0, sections].join('/'), '')
            end
        end

        def alias_template(destination_path)
<<-EOF
<!DOCTYPE html>
<html>
<head>
<link rel="canonical" href="#{destination_path}"/>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<meta http-equiv="refresh" content="0;url=#{destination_path}" />
</head>
</html>
EOF
        end

    end
end
