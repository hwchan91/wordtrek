class WordTrek
  require_relative "dict"
  require_relative "word"
  attr_accessor :top_stack, :bottom_stack, :curr_stack, :top_front, :bottom_front, :curr_front, :to_be_added, :new_transition_words, :words_in_curr_stack, :words_in_to_be_added, :to_be_added, :result

  def initialize(starting_word, target_word, dict = nil)
    unless dict
      @curr_front = @top_front = [Word.new(starting_word, target_word)]
      @bottom_front = [Word.new(target_word, starting_word)]
    else
      @curr_front = @top_front = [Word.new(starting_word, target_word, dict)]
      @bottom_front = [Word.new(target_word, starting_word, dict)]
    end
    @fronts = [@top_front, @bottom_front]
  
    @curr_stack = @top_stack = []
    @bottom_stack = []
    @stacks = [@top_stack, @bottom_stack]
    @curr_side_index = 0

    @result = nil
  end

  def switch_sides
    @curr_stack =  @stacks[(@curr_side_index + 1) % 2]
    @curr_front = @fronts[(@curr_side_index + 1) % 2]
  end

  def opposite_stack
    @stacks[(@curr_side_index + 1) % 2]
  end

  def opposite_front
    @fronts[(@curr_side_index + 1) % 2]
  end

  def find_solution #should not be curr_stack but the front of new trasition words
    catch :found_solution do 
      propagate_front
      check_if_no_solution
      move_front
    end
    return_solution if @result
  end

  def return_solution
    return 'no solution' if @result == 'no solution'
    first_half = @result[0].path 
    second_half = @result[1].path 
    first_half + [@result[0].word] + second_half
  end

  def move_front
    clear_curr_stack_cache
    @curr_stack += @curr_front
    @curr_front = @to_be_added
  end

  def propagate_front(front = @curr_front, to_be_added = @to_be_added = [])
    wordbase = front.clone #unlink from the front so that the front would remain the same
    wordbase.each do |word|
      word.transition_word_objects.each do |transition_word|
        check_if_reached_target(transition_word)
        to_be_added << transition_word if new_word?(transition_word)
      end
      clear_to_be_added_cache

      recursive_call_on_words_getting_closer(word, to_be_added) if word.getting_closer? #recursive call should be after add_if_new for optimal path 
    end
    to_be_added
  end

  def clear_to_be_added_cache
    remove_instance_variable(:@words_in_to_be_added)if @words_in_to_be_added
  end

  def clear_curr_stack_cache
    remove_instance_variable(:@words_in_curr_stack) if @words_in_curr_stack
  end

  def check_if_reached_target(word)
    opposite_side = opposite_stack + opposite_front
    opposite_side.each do |word_in_oppo|
      if word.word  == word_in_oppo.word
        @result = [word, word_in_oppo]
        throw :found_solution
      end
    end
  end

  def check_if_no_solution
    if @to_be_added.empty?
      @result = "no solution" 
      throw :found_solution
    end
  end

  def recursive_call_on_words_getting_closer(word, to_be_added)
    words_closer = word.transition_words_closer_to_target
    propagate_front(words_closer, to_be_added)
  end

  def new_word?(word)
    @words_in_curr_stack ||= words_in_stack(@curr_stack)
    @words_in_to_be_added ||= words_in_stack(@to_be_added)

    not_in_stack = !@words_in_curr_stack.include?(word.word)
    not_in_to_be_added = !@words_in_to_be_added.include?(word.word)
    not_in_stack and not_in_to_be_added
  end

  def words_in_stack(stack)
    (stack.empty?) ? [] : stack.map(&:word)
  end


end

# w = WordTrek.new('apple', 'lemon')
# w.add_transition_to_stack
# w.add_transition_to_stack
# w.words_in_stack(w.curr_stack).length

# w = WordTrek.new('aaaaa', 'zzzzz')
# w.add_transition_to_stack


 binding.pry
