require 'singleton'
require 'fastimage'
require 'yaml'
require 'net/http'

class ImageHelper
  include Singleton
  attr_accessor :img_size_cache, :fb_image_cache

  def load
    @img_size_cache = File.exists?("_img_size_cache") ? YAML.load(File.read("_img_size_cache")) : {}
    @fb = @img_size_cache['fb']
    @photo = @img_size_cache['photo']
    @post_thumb_sm = @img_size_cache['post_thumb_sm']
    @post_thumb_lg = @img_size_cache['post_thumb_lg']
    puts "Image sizes cache loaded. #{@img_size_cache.count} keys"
  end

  def save
    puts "Image sizes cache saving. #{@img_size_cache.count} keys"
    File.write("_img_size_cache", YAML.dump(@img_size_cache))
  end

  def size(path, post, name)
    key = post + name
    @photo[key] = FastImage.size(path) unless (@photo.has_key?(key) and @photo[key])
    return @photo[key]
  end

  def fb_image(post)
    @fb[post] = probe_list(post, ['title-fb.jpg', 'title@2x.jpg', 'title.jpg', 'title-s@2x.jpg', 'title-s.jpg']) unless (@fb.has_key?(post) and @fb[post])
    "http://gaziga.com#{post}/#{@fb[post]}"
  end

  def thumb_sm(post)
    @post_thumb_sm[post] = probe_list(post, ['title-s@2x.jpg', 'title-s.jpg']) unless (@post_thumb_sm.has_key?(post) and @post_thumb_sm[post])
    "#{post}/#{@post_thumb_sm[post]}"
  end

  def thumb_lg(post)
    @post_thumb_lg[post] = probe_list(post, ['title@2x.jpg', 'title.jpg']) unless (@post_thumb_lg.has_key?(post) and @post_thumb_lg[post])
    "#{post}/#{@post_thumb_lg[post]}"
  end

  def probe_list(post, img_list)
    img_list.each do |img|
      url = probe(post, img)
      return img if url
    end
    nil
  end

  def probe(post, img)
    http = Net::HTTP.new('gaziga.com', 80)
    response = http.request_head("#{post}/#{img}")
    response.code == '200' ? img : nil
  end


end

module Jekyll
  class Site
    alias orig_process process

    def process
      ImageHelper.instance.load
      orig_process
      ImageHelper.instance.save
    end
  end
end
