module Jekyll
    module Generators

        class Feed
            attr_accessor :posts

            def initialize(posts)
                @posts = posts
            end

            def to_liquid
                {
                    'posts' => @posts
                }
            end
        end

        class Paginator
            attr_accessor :posts, :next_page, :prev_page, :total_pages, :page

            def initialize(posts, total_pages, page)
                @posts = posts
                @page = page
                @total_pages = total_pages
            end

            def to_liquid
                {
                    'posts' => @posts,
                    'page' => @page,
                    'total_pages' => @total_pages,
                    'next_page' => @next_page,
                    'previous_page' => @prev_page,
                    'next_page_path' => @next_page ? @next_page.url.gsub('index.html', '') : nil,
                    'previous_page_path' => @prev_page ? @prev_page.url.gsub('index.html', '') : nil
                }
            end

            def self.generate_pages(site, taxonomy_name, taxonomy_val, posts, per_page)

                taxonomy_names = [*taxonomy_name]
                taxonomy_name = taxonomy_names[0]
                original_taxonomy_val = taxonomy_val
                taxonomy_val = Jekyll::GazigaFilter.slugify(taxonomy_val)


                dir = File.join(taxonomy_name, taxonomy_val)
                pages = []
                posts.sort_by{|p| p.date}.reverse.each_slice(per_page).each_with_index do |page_posts, i|
                    paginator = Paginator.new(page_posts, (posts.length/per_page.to_f).ceil, i+1)
                    page_dir = i == 0 ? dir : File.join(dir, "page#{i+1}")
                    page = TaxonomyPage.new(site, taxonomy_name, taxonomy_val, site.source, page_dir, paginator)
                    page.data['title'] = original_taxonomy_val
                    page.data['alias'] ||= Array.new

                    taxonomy_names.each do |tax_alias|
                        page.data['alias'] << "#{tax_alias}/#{original_taxonomy_val.downcase}"
                        page.data['alias'] << "#{tax_alias}/#{original_taxonomy_val.downcase.gsub(/-/, ' ')}"
                        page.data['alias'] << "#{tax_alias}/#{original_taxonomy_val.downcase.gsub(/-/, '_')}"
                        page.data['alias'] << "#{tax_alias}/#{original_taxonomy_val.downcase.gsub(" ", '-')}"
                        page.data['alias'] << "#{tax_alias}/#{taxonomy_val}"
                    end

                    pages << page
                end

                pages.each_cons(2) { |p, n|
                    p.paginator.next_page = n
                    n.paginator.prev_page = p
                }
                pages << FeedXml.new(site, taxonomy_name, taxonomy_val, site.source, dir, Feed.new(posts))
                pages
            end
        end

        class FeedXml < Page
            def initialize(site, taxonomy_name, taxonomy_val, base, dir, feed)
                @site = site
                @base = base
                @dir = dir
                @name = "feed.xml"
                @feed = feed
                self.process(@name)
                self.read_yaml(base, "feed.xml")
                self.data[taxonomy_name] = taxonomy_val
            end

            def render(layouts, site_payload)
                payload = Utils.deep_merge_hashes(
                    {
                        'feed' => @feed.to_liquid
                    }, site_payload)

                super(layouts, payload)
            end

        end

        class TaxonomyIndex < Page
            def initialize(site, taxonomy_name, base, dir, pages)
                @site = site
                @base = base
                @dir = dir
                @name = "index.html"
                @pages = pages
                self.process(@name)
                self.read_yaml(base, "_layouts/taxonomy-index.html")
                self.data['title'] = taxonomy_name + 's'
                self.data['alias'] ||= []
                self.data['alias'] << "#{taxonomy_name}s"
            end

            def render(layouts, site_payload)
                payload = Utils.deep_merge_hashes(
                    {
                        'pages' => @pages
                    }, site_payload)

                super(layouts, payload)
            end

        end

        class TaxonomyPage < Page
            attr_accessor :paginator

            def initialize(site, taxonomy_name, taxonomy_val, base, dir, paginator)
                @taxonomy_val = taxonomy_val
                @title =  @taxonomy_val
                @taxonomy_name = taxonomy_name
                @site = site
                @base = base
                @dir = dir
                @name = "index.html"
                @paginator = paginator
                self.process(@name)
                self.read_yaml(base, "_layouts/taxonomy-page.html")
                self.data[taxonomy_name] = taxonomy_val
            end

            def render(layouts, site_payload)
                @taxonomy_val.chomp! '/'
                payload = Utils.deep_merge_hashes(
                        {
                            'taxonomy_name' => @taxonomy_name,
                            'taxonomy_val' => @taxonomy_val,
                            'paginator' => @paginator.to_liquid
                        }, site_payload)

                super(layouts, payload)
            end
        end

        class TaxonomyGenerator < Generator
            priority :low

            def get_pages(site)
                []
            end

            def generate(site)
                return if self.class == TaxonomyGenerator
                @taxonomy_name = self.class.name.split('::').last.gsub('Pagination', '').downcase
                pages = get_pages(site)
                site.pages.concat(pages)

                pages = pages.select{|p| p.is_a?(TaxonomyPage)}.reject{|p| p.dir.match('\/page\d+')}
                site.pages << TaxonomyIndex.new(site, @taxonomy_name, site.source, @taxonomy_name, pages)
            end
        end

        class GeoPagination < TaxonomyGenerator
            def get_pages(site)
                pages = []
                for category in site.categories.keys
                    pages.concat(Paginator.generate_pages(site, 'geo', category, site.categories[category], site.config['paginate']))
                end
                pages
            end
        end

        class TagPagination < TaxonomyGenerator
            def get_pages(site)
                pages = []
                for tag in site.tags.keys
                    pages.concat(Paginator.generate_pages(site, ['tag', 'tags'], tag, site.tags[tag], site.config['paginate']))
                end
                pages
            end
        end

        class AuthorPagination < TaxonomyGenerator
            def get_pages(site)
                pages = []
                for author in ['gagarin', 'uma']
                    pages.concat(Paginator.generate_pages(site, 'author', author, site.posts.select{|p| p['author'] == author}.to_a, site.config['paginate']))
                end
                pages
            end
        end
    end
end


