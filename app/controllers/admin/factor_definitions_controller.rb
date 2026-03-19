# frozen_string_literal: true

module Admin
  class FactorDefinitionsController < ApplicationController
    before_action :require_user
    before_action :set_factor, only: %i[show edit update toggle]

    def index
      @factors = FactorDefinition.ordered
      @latest_report = DailyReport.latest_for_type('factor')
    end

    def matrix
      @factors = FactorDefinition.active.ordered

      # 获取最新的因子值，按 asset_id 和 factor_definition_id 分组
      @factor_values = FactorValue.latest.includes(:asset, :factor_definition)
      @values_by_asset = @factor_values.group_by(&:asset_id).transform_values do |values|
        values.index_by { |v| v.factor_definition_id }
      end

      # 获取市值前 50 的资产并计算排序
      @assets = sort_assets(
        Asset.where.not(market_cap_rank: nil).where("market_cap_rank <= 50").to_a,
        @factors,
        @values_by_asset
      )

      # 当前排序参数
      @sort_by = params[:sort_by] || "composite"
      @sort_order = params[:sort_order] || "desc"
    end

    def correlations
      @factors = FactorDefinition.active.ordered

      # 获取最新的因子值
      @factor_values = FactorValue.latest.includes(:factor_definition)

      # 按因子分组，得到每个因子在所有资产上的值
      @values_by_factor = @factor_values.group_by(&:factor_definition_id)

      # 计算因子间相关性矩阵
      @correlation_matrix = calculate_correlation_matrix(@factors, @values_by_factor)

      # 识别高相关性因子对
      @high_correlations = find_high_correlations(@factors, @correlation_matrix)
    end

    def show; end

    def edit; end

    def update
      if @factor.update(factor_params)
        redirect_to admin_factor_definition_path(@factor), notice: "因子更新成功"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle
      @factor.update!(active: !@factor.active)
      status_text = @factor.active? ? "启用" : "禁用"
      redirect_to admin_factor_definitions_path, notice: "因子已#{status_text}"
    end

    private

    def set_factor
      @factor = FactorDefinition.find(params[:id])
    end

    def factor_params
      params.require(:factor_definition).permit(
        :name,
        :description,
        :category,
        :weight,
        :active,
        :update_frequency,
        parameters: {}
      )
    end

    def calculate_correlation_matrix(factors, values_by_factor)
      matrix = {}

      factors.each do |factor_a|
        matrix[factor_a.id] = {}

        factors.each do |factor_b|
          if factor_a.id == factor_b.id
            matrix[factor_a.id][factor_b.id] = 1.0
          else
            # 获取两个因子的值序列
            values_a = values_by_factor[factor_a.id]&.map(&:normalized_value) || []
            values_b = values_by_factor[factor_b.id]&.map(&:normalized_value) || []

            # 计算相关系数
            correlation = calculate_pearson_correlation(values_a, values_b)
            matrix[factor_a.id][factor_b.id] = correlation
          end
        end
      end

      matrix
    end

    def calculate_pearson_correlation(x, y)
      return 0 if x.empty? || y.empty? || x.size != y.size

      n = x.size
      mean_x = x.sum / n.to_f
      mean_y = y.sum / n.to_f

      numerator = x.each_with_index.sum { |xi, i| (xi - mean_x) * (y[i] - mean_y) }
      denominator_x = Math.sqrt(x.sum { |xi| (xi - mean_x) ** 2 })
      denominator_y = Math.sqrt(y.sum { |yi| (yi - mean_y) ** 2 })

      return 0 if denominator_x.zero? || denominator_y.zero?

      numerator / (denominator_x * denominator_y)
    end

    def find_high_correlations(factors, matrix)
      high_corr = []
      threshold = 0.6

      factors.each_with_index do |factor_a, i|
        factors.each_with_index do |factor_b, j|
          next if i >= j  # 只计算上三角，避免重复

          correlation = matrix[factor_a.id][factor_b.id]
          if correlation.abs >= threshold
            high_corr << {
              factor_a: factor_a,
              factor_b: factor_b,
              correlation: correlation
            }
          end
        end
      end

      high_corr.sort_by { |c| -c[:correlation].abs }
    end

    def sort_assets(assets, factors, values_by_asset)
      sort_by = params[:sort_by] || "composite"
      sort_order = params[:sort_order] || "desc"

      # 计算每个资产的排序值
      assets_with_scores = assets.map do |asset|
        asset_values = values_by_asset[asset.id] || {}

        # 计算综合评分
        total_score = 0
        total_weight = 0
        factors.each do |factor|
          factor_value = asset_values[factor.id]
          if factor_value
            total_score += factor_value.normalized_value * factor.weight
            total_weight += factor.weight
          end
        end
        composite_score = total_weight > 0 ? (total_score / total_weight) : 0

        # 获取指定因子的值
        factor_score = if sort_by != "composite"
          factor = factors.find { |f| f.id.to_s == sort_by }
          factor_value = asset_values[factor&.id]
          factor_value&.normalized_value || 0
        else
          composite_score
        end

        {
          asset: asset,
          score: factor_score,
          composite_score: composite_score
        }
      end

      # 排序
      sorted = assets_with_scores.sort_by { |item| item[:score] }
      sorted = sorted.reverse if sort_order == "desc"

      sorted.map { |item| item[:asset] }
    end
  end
end
