module Admin::FactorDefinitionsHelper
  def factor_value_class(value)
    num_value = value.to_f
    if num_value > 0.3
      'factor-matrix-value--positive'
    elsif num_value < -0.3
      'factor-matrix-value--negative'
    else
      'factor-matrix-value--neutral'
    end
  end

  def correlation_cell_class(value)
    num_value = value.to_f
    if num_value >= 0.6
      'factor-correlation-value--high-positive'
    elsif num_value >= 0.3
      'factor-correlation-value--low-positive'
    elsif num_value >= -0.3
      'factor-correlation-value--neutral'
    elsif num_value >= -0.6
      'factor-correlation-value--low-negative'
    else
      'factor-correlation-value--high-negative'
    end
  end
end
