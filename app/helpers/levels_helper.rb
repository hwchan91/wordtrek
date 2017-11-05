module LevelsHelper
  def choosable?(index)
    @choices[index] ? 'choosable' : 'unchoosable'
  end
  
  def number_of_prev_steps_exceed(num)
    @history.length > num
  end

  def range_of_prev_steps(num)
    (-(num + 1)..-2).to_a
  end

  def history_at(number_of_prev_steps)
    @history[number_of_prev_steps]
  end 

  def distance_from_curr(number_of_prev_steps) 
    if @undo
       -(number_of_prev_steps) - 1 
    else
      -(number_of_prev_steps) - 2
    end
  end

  def backstep(number_of_prev_steps)
    -(number_of_prev_steps) - 1
  end

  def highlight_letter_if_changed(letter_index, changed_index)
    return "highlight" if reorder_letters?(changed_index)
    "highlight" if letter_index == changed_index
  end

  def reorder_letters?(changed_index)
    changed_index.nil? #nil signifies reorder, "none"(defined below) signifies starting word
  end

  def describe_action(changed_index)
    changed_index ? "switch_index_#{changed_index}" : "reorder_letters"
  end

  def used_word(record)
    record["word"]
  end

  def changed_index(record)
    changed_index = record["changed_index"]
    changed_index.nil? ? "none" : changed_index.to_i
  end

end
