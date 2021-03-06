class LevelsController < ApplicationController
  before_action :get_completed_levels
  before_action :check_if_hack, only: [:show, :move, :reset, :undo]
  before_action :set_level, only: [:show, :move]
  before_action :get_word, only: [:show]
  before_action :get_chapter, only: [:index]

  def show
    respond_to do |format|
      format.html do
        if complete
          @complete = true
          update_records
          render 'complete'
        else
          render 'show'
        end
      end
      format.js { reload_show }
    end
  end

  def move
    new_word = params[:word]
    history = session[:"level#{params[:id]}_history"] ||= [] #empty array is necc for valid_transition method
    if last_word.valid_transition?(new_word, history)
      if session[:"level#{params[:id]}_history"]
        session[:"level#{params[:id]}_history"] << word_hash
      else
        session[:"level#{params[:id]}_history"] = [word_hash]
      end
    end
    reload_show
  end

  def reset
    session[:"level#{params[:id]}_history"] = nil
    reload_show
  end

  def undo
    undo_to_index = -(params[:steps].to_i + 1)
    history = session[:"level#{params[:id]}_history"]
    session[:"level#{params[:id]}_history"] = history[0..undo_to_index] unless history.length <= 1

    @undo = true
    reload_show
  end

  def index
    @user = current_user
    @levels = Level.default.where(id: ((@chapter-1) * 10 + 1).. ((@chapter-1) * 10 + 10)).order(:id)
    @level = @levels.last
    @chapter_title = Chapter.find(@chapter).name

    respond_to do |format|
      format.html
      format.js
    end
  end

  def home
    @user = current_user
    @level = Level.first
    respond_to do |format|
      format.html
      format.js
    end
  end

  def skip_zen_level
    unless params[:id] == 'zen'
      redirect_to levels_path, format: :js
    end

    @skip_interstitial = true if params[:skip_interstitial]

    current_user.update!(continuous_zen_levels: 0)
    cookies.permanent.encrypted[:zen] = nil
    session[:"levelzen_history"] = nil
    render 'loading.js'
  end

  def loading
    render 'loading.js'
  end

  def get_hints
    level_id = params[:id].to_s
    @level = Level.find(params[:id])

    if current_user.hints[level_id].nil?
      @hints_count = current_user.hints[level_id] = 1
    else
      count = current_user.hints[level_id]
      @hints_count = current_user.hints[level_id] = count + 1
    end
    current_user.save
    render 'get_hints.js'
  end

  private
    def set_level
      @user = current_user
      unless params[:id] == 'zen'
        @level = Level.default.find(params[:id])
        if @level.path.count == 2
          @hints_count = 0
        else
          @hints_count = [(@user.hints[@level.id.to_s] || 0), (@level.path.count-1)/2].min
        end
      else
        set_zen_level
      end

      @limit = case @level.id
      when *[1..20] then @level.path.size + 3
      when *[21..40] + [9999] then @level.path.size + 2
      else @level.path.size + 1
      end

      set_history
    end

    def set_zen_level
      cookies.permanent.encrypted[:zen] = Level.random.as_json.to_json if cookies.encrypted[:zen].nil?
      level_in_json = cookies.encrypted[:zen].clone
      @level = OpenStruct.new(JSON.parse(level_in_json))
      @hints_count = 0
      @skip_interstitial = true if params[:skip_interstitial]
    end

    def set_history
      if session[:"level#{params[:id]}_history"].is_a? Array
        @history = session[:"level#{params[:id]}_history"]
      else
        @history = session[:"level#{params[:id]}_history"] = [ {"word" => @level.start, "changed_index" => nil } ]
      end
    end

    def get_word
      @word = last_word
      @choices = @word.choices(@history.map{|hash| hash["word"]})
      @definition = @word.define
      @matches = @word.compare(@level.target)
    end

    def last_word
      (@history and @history.any?) ? Word.new(@history[-1]["word"]) : Word.new(@level.start)
    end

    def complete
      @level.target == @word.word
    end

    def reload_show
      set_level
      get_word

      if complete
        @complete = true
        unless params[:id] == 'zen'
          update_records
        else
          update_zen_records
        end
        render 'complete.js'
      else
        render 'reload_show.js'
      end
    end

    def word_hash
      {"word" => params[:word], "changed_index" => params[:changed_index]}
    end

    def update_records
      level_id = params[:id]
      path = session[:"level#{level_id}_history"]
      optimal_achieved = path.length == @level.path.length
      completed_levels = current_user.completed_levels.map(&:to_i)
      optimal_levels = current_user.optimal_levels.map(&:to_i)

      unless completed_levels.any?{|id| id == @level.id }
        current_user.completed_levels << @level.id
        @show_rate_dialog = true if @level.id.in?([7,10,15,20,25,30,35,40,45,50]) && !current_user.has_rated
      end

      if optimal_achieved
        unless optimal_levels.any?{|id| id == @level.id }
          current_user.optimal_levels << @level.id
          @zen_unlocked = true if optimal_levels.count == 20
        end
      end

      current_user.save!

      session.delete(:"level#{params[:id]}_history")
    end

    def update_zen_records
      current_user.total_completed_zen_levels = current_user.total_completed_zen_levels.to_i + 1
      current_user.continuous_zen_levels = current_user.continuous_zen_levels.to_i + 1
      current_user.optimal_zen_levels = current_user.optimal_zen_levels.to_i + 1
      current_user.save!

      session.delete(:"level#{params[:id]}_history")
      cookies.permanent.encrypted[:zen] = Level.random.as_json.to_json
    end

    def get_completed_levels
      @completed_levels = current_user.completed_levels.map(&:to_i)
      @optimal_levels = current_user.optimal_levels.map(&:to_i)
    end

    def check_if_hack
      return if params[:id] == 'zen'
      latest_level = @completed_levels.max
      if (latest_level and params[:id].to_i > latest_level.to_i + 1 ) or (latest_level.nil? and params[:id].to_i > 1 )
        redirect_to levels_path, format: :js
      end
    end

    def get_chapter
      @curr_chapter = @completed_levels.empty? ?  1 : (@completed_levels.max / 10 ) + 1
      @chapter = params[:chapter].nil? ? @curr_chapter : params[:chapter].to_i
      # no cheating
      if params[:chapter] and (@completed_levels.empty? or (@completed_levels.max / 10) + 1 < @chapter)
        @chapter = @curr_chapter
      end
      max_chapter = ENV['DEFAULT_CHAPTERS'].to_i
      @chapter = max_chapter if @chapter > max_chapter
    end

end
