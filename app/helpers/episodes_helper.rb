require "digest/md5"
module EpisodesHelper
  def link_to_play(episode)
    link_to_remote "play", {:url => {:action => "play", :episode => episode}}, {:class => "play"}
  end

  def link_to_seen(episode)
    link_to_remote "toggle seen", {:url => {:action => "seen", :episode => episode}}, {:class => "seen"}
  end

  def link_to_stop
    link_to_remote "stop", :url => {:controller => :episodes, :action => "stop"}, :html => {:class => "stop"}
  end

  def link_to_pause
    link_to_remote "play/pause", :url => {:controller => :episodes, :action => "pause"}
  end

  def currently_playing?(episode = :anything)
    @currently_playing_episode == episode or episode == :anything and not @currently_playing_episode.nil?
  end

  def currently_playing_name
    h File.basename(@currently_playing_episode.filename)
  end

  def paused?
    @paused
  end
end
