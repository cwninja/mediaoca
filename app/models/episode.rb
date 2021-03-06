class Episode < ActiveRecord::Base
  include Comparable
  named_scope :unwatched, {:conditions => {:last_watched => nil}}
  named_scope :watched, {:conditions => "last_watched is not null"}

  EPISODE_MATCHERS = [/([0-9]{1,2})x([0-9]{1,2})/i, /s([0-9]{1,2})e([0-9]{1,2})/i]
  belongs_to :show

  module CollectionMethods
    def latest
      @latest ||= reject(&:seen?).sort_by{|e| e.series_and_episode ? e.series_and_episode : [0,0]}
    end

    def last_changed
      map(&:created_at).max
    end

    def most_recently_seen
      map(&:seen).max
    end
  end

  class << self
    def file_digest(file)
      Digest::MD5.hexdigest(file)
    end

    def find_or_create_by_filename(filename)
      hash = file_digest(File.basename(filename))
      if ep = find_by_hash_code(file_digest(filename))
        ep.update_attribute(:hash_code, hash)
        ep
      else
        find_or_create_by_hash_code(hash)
      end
    end

    def for(filename)
      returning find_or_create_by_filename(filename) do |e|
        e.filename = filename
        e.show ||= Show.guess_show(e)
        e.save!
      end
    end

    def clenseables
      @clenseables ||= Regexp.new(YAML.load(File.open(File.join(Rails.root, "config", "clenseables.yml"))).join("|"))
    end

    def media_paths
      @media_paths ||= YAML.load(File.open(File.join(Rails.root, "config", "media_paths.yml")))
    end

    def scan_for_episodes!
      media_paths.map{|path|
        Dir.glob("#{path}/**/*.{avi,wmv,divx,mkv,ts,mov,mp4,m4v}")
      }.flatten.reject{|filename|
        File.basename(filename) =~ /([ -.({]|^)sample([ -.)}]|$)/i
      }.map{|filename|
        Episode.for(filename)
      }
    end

    def detect_missing_shows!
      find_all_by_show_id(nil).each{|e| e.show = Show.guess_show(e); e.save! }
    end

    def clean_up_deleted_episodes!
      all.each do |episode|
        episode.destroy if episode.filename.nil? or not File.exist?(episode.filename)
      end
    end
  end

  def name
    returning File.basename(filename) do |name|
      name[/\.[^.]+$/] = " "
      name.gsub!("."," ")
      name.gsub!(self.class.clenseables, " ")
      name.sub!(/#{show.name}/, " ") if show
      EPISODE_MATCHERS.each do |em|
        name.sub!(em, "") if series_and_episode
      end
      name.gsub!("[ ]+"," ")
    end
  end

  def series
    series_and_episode && series_and_episode.first
  end

  def episode
    series_and_episode && series_and_episode.last
  end

  def series_and_episode
    @series_and_episode ||= [
      if EPISODE_MATCHERS.any?{|re| filename =~ re }
        [$1.to_i, $2.to_i]
      else
        nil
      end ].first
  end

  def unknown_episode?
    series_and_episode.nil? || !series_and_episode.all?
  end

  def seen
    last_watched?
  end

  def seen?
    last_watched?
  end

  def seen!
    self.seen = true
  end

  def <=>(other)
    sorter = proc{|e| [e.seen? && 1, e.show && e.show.name || "", e.series, e.episode, e.name ].map{|e| e || 0 }}
    sorter[self] <=> sorter[other]
  end

  def seen=(bool)
    update_attribute(:last_watched, bool ? Time.now : nil)
  end
end
