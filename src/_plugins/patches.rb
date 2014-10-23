#force jekyll to create directories
module Jekyll
  class Page
     alias orig_template template

     def template
        return '/:basename/index.html' if basename != "index" && output_ext == ".html"
        orig_template
     end
  end


  class Post
    alias orig_initialize initialize

    def initialize(site, source, dir, name)
      orig_initialize(site, source, dir, name)
      # puts File.expand_path(self.dir)
      # puts "#{self.id}/*.*"
      # puts Dir["#{self.id}/*.*"]
    end
  end
end
