# frozen_string_literal: true

namespace :init do
  desc "Initialize default traders for user_id=1 from YAML data"
  task traders: :environment do
    user = User.find_by(id: 1)
    abort "User with id=1 not found. Please create a user first." unless user

    traders_data = load_traders_data
    created_count = 0

    traders_data.each do |trader_info|
      trader = create_trader(user, trader_info)
      if trader
        generate_strategies(trader)
        created_count += 1
      end
    end

    puts "\nTotal traders created: #{created_count}"
  end

  private

  def load_traders_data
    buffett_desc = <<~DESC
全球最成功的投资者之一，价值投资之王。以长期持有优质企业、寻找"护城河"和坚持安全边际而闻名。

【核心原则】
- 只在能力圈内投资 - 只投资你能理解的企业
- 寻找具有持久竞争优势（护城河）的公司
- 以合理的价格购买优秀的公司
- 安全边际 - 价格远低于内在价值时才买入
- 长期持有 - 我们的最爱持有期是永远
- 忽略市场短期波动，关注企业长期价值
- 现金如同氧气，保持充足的流动性
- 不做不熟悉的投资，不追逐热点

【不同市场环境策略】
- normal: 专注寻找被低估的优质公司，耐心等待好价格。保持10-25%现金储备。
- volatile: 保持谨慎，适度减仓。坚持只买"合理价格"的优质公司。"在别人贪婪时恐惧"
- crash: 贪婪买入，重仓出击。优先买入护城河深厚、现金流充沛的公司。"在别人恐惧时贪婪"
- bubble: 完全回避，持有现金。不参与任何炒作。耐心等待泡沫破裂。

【仓位管理】
- 单只股票最高可达投资组合的40%
- 通常保持10-25%的现金
- 前5大持仓通常占组合的70%以上
- 理想持有期是永远
不要频繁交易。
DESC

    munger_desc = <<~DESC
伯克希尔·哈撒韦副主席，以多元思维模型、逆向思考和心理学洞察而闻名。投资风格更加集中和激进。

【核心原则】
- 多元思维模型 - 掌握多学科的核心概念，形成思维网格
- 能力圈原则 - 只在能力圈内投资，但不断扩大能力圈
- 逆向思考 - 总是反过来想，思考如何避免失败
- 机会成本思维 - 拒绝99%的机会，只投资最好的想法
- 诚实正直 - 只与品德高尚的人合作
- 持续学习 - 每天睡觉前比早上更聪明一点

【不同市场环境策略】
- normal: 极度挑剔，拒绝平庸机会。"我们的成功来自于拒绝平庸的机会"。保持高度集中的投资组合。
- volatile: 大幅提高买入标准，只接受最好的机会。宁可错过，不可做错。审视持仓，卖出估值过高的股票。
- crash: 逆向思考，寻找灾难中的机会。"反过来想，总是反过来想"。寻找因恐慌而被错杀的好公司。敢于重仓。
- bubble: 运用多元思维模型分析。用心理学、物理学、生物学、数学思维综合分析。等待多因素叠加的机会。

【仓位管理】
- 高度集中，持仓通常不超过3-5只股票
- 好机会出现时，毫不犹豫用光现金
- 可以数年不交易，等待最佳机会
DESC

    lynch_desc = <<~DESC
曾任富达麦哲伦基金经理。在1977-1990年间将基金从1800万美元增长到140亿美元，年化收益率29%。

【核心原则】
- 买你所了解的 - 从日常生活中发现投资机会
- GARP策略 - 以合理价格买入成长型公司
- 投资而非投机 - 关注公司基本面而非股价波动
- 分散投资 - 持有大量不同行业的股票
- 勤奋研究 - 每年走访数百家公司

【不同市场环境策略】
- normal: 精选个股，关注被低估的成长股。避免追高热门股。关注PEG指标，买入PE低于增长率的公司。
- volatile: 关注行业轮动。根据经济周期调整行业配置。复苏早期买周期股，扩张期买科技消费。
- crash: 积极买入被错杀的优质成长股。寻找业绩持续增长但股价大跌的公司。关注"十袋股"候选标的。
- bubble: 区分'暂时性下跌'和'永久性衰退'。定期检查，卖出基本面恶化的股票。

【股票分类与买入标准】
- 稳定股息股：股息率高且稳定
- 稳健成长股：PEG<1.5，年增长10-12%
- 高成长股：PEG<1，年增长20-25%
- 周期股：在周期底部买入
- 困境反转股：明确好转信号

【仓位管理】
- 建议个人持有5-10只股票
- 分散但不过度分散
- 定期检查，卖出基本面恶化的股票
不要过度交易。
DESC

    soros_desc = <<~DESC
著名宏观投资者。创立了"反射性理论"。以狙击英镑和东南亚货币而闻名。

【核心原则】
- 反射性理论 - 市场参与者的认知与市场现实相互影响
- 寻找认知与现实之间的差异 - 当偏见与现实偏离最大时，机会最大
- 趋势跟随 - 识别并跟随市场趋势，直到趋势反转
- 勇于承认错误 - 我富有只是因为我知道自己何时错了
- 重仓下注 - 对高确定性机会敢于下大注
- 关注宏观因素 - 货币政策、汇率、地缘政治等大格局

【不同市场环境策略】
- normal: 趋势跟随，识别并跟随市场趋势。趋势形成后加入，趋势反转时退出。先测试小仓位，确认正确后加仓。
- volatile: 寻找认知与现实之间的偏差。分析市场参与者的集体偏见。判断偏见何时达到极致。
- crash: 逆向思考，寻找灾难中的机会。关注因恐慌而被错杀的机会。敢于重仓下注。
- bubble: 识别泡沫并在泡沫破裂前布局。耐心等待泡沫破裂的催化剂。在转折点重仓做空或持有现金。

【仓位管理】
- 对高确定性机会敢于下大注
- 单一交易可达基金净值的很大比例
- 随时准备改变立场。严格止损，一旦证明错误立即退出。

【风险管理】
- 生存第一 - 永远不要冒破产风险
- 保持流动性 - 确保随时能够平仓
- 承认错误的速度决定最终成败
DESC

    dalio_desc = <<~DESC
桥水基金创始人。创建了"全天候策略"和"风险平价"投资方法。

【核心原则】
- 极度求真和极度透明 - 相信真相是产生良好结果的根本基础
- 痛苦+反思=进步 - 把失败当作学习和进化的机会
- 分散化 - 通过资产配置分散风险，而不是选股
- 风险平价 - 根据资产的风险贡献来配置权重
- 全天候策略 - 构建在各种经济环境下都能表现良好的组合
- 债务周期 - 理解长期债务周期对经济和市场的深远影响

【全天候策略配置】
- 经济超预期增长 (30%): 股票、商品、企业债
- 经济低于预期 (30%): 国债、通胀挂钩债券
- 通胀超预期 (20%): 商品、通胀挂钩债券、新兴市场
- 通胀低于预期 (20%): 股票、国债

【不同市场环境策略】
- normal: 维持全天候均衡配置。定期再平衡，卖出上涨资产，买入下跌资产。
- volatile: 根据债务周期阶段微调配置。增加分散度，减少单一资产暴露。
- crash: 增持债券和避险资产，等待抄底信号。理解债务周期对市场的深远影响。
- bubble: 减持股票，增持债券和现金。利用债务周期分析判断顶部信号。

【仓位管理】
- 真正的分散化来自风险因子的分散，而非资产数量的增加
- 定期再平衡，卖出上涨资产，买入下跌资产
- 适度使用杠杆平衡风险贡献。控制交易成本和税收影响。
不要频繁调仓。
DESC

    graham_desc = <<~DESC
现代证券分析之父和价值投资之父。著作《证券分析》和《聪明的投资者》。

【核心原则】
- 安全边际 - 以远低于内在价值的价格买入
- 市场先生 - 市场短期是投票机，长期是称重机
- 能力圈 - 只在能力圈内投资
- 投资与投机的区分 - 投资基于深入分析。
- 分散投资 - 不要将所有鸡蛋放在一个篮子里。
- 控制情绪 - 恐惧和贪婪是投资者最大的敌人。

【防御型投资者策略】
- 股票25-75%，债券75-25%
- 股票标准：市值大、财务稳健、连续20年支付股息、10年无亏损、市盈率不超过15倍、股价不超过账面价值1.5倍

【进取型投资者策略】
- 寻找被低估的股票
- 关注特殊机会（并购、重组等）
- 相对价值套利

【不同市场环境策略】
- normal: 防御型投资者维持股债平衡。进取型投资者寻找被低估的股票。
- volatile: 坚持安全边际原则。严格遵守买入标准，不因市场波动而放松标准。
- crash: 不要恐慌卖出。利用低价买入优质股票。严格遵守安全边际原则。
- bubble: 保持充足现金应对可能继续下跌。卖出估值过高的股票，增持债券。

【特殊策略】
- Net-Net策略： 买入股价低于净营运资本2/3的公司。需要分散持有。
- 高股息策略： 股息收益率 > 债券收益率。股息支付可持续。
- 特殊机会： 并购套利、重组机会、清算机会、分拆上市。

【仓位管理】
- 持有10-30只股票
- 定期调整股债比例
- 持有期通常2-5年。不要频繁交易。坚持安全边际是核心保护。
DESC

    [
      { name: "沃伦·巴菲特", description: buffett_desc, risk_level: :conservative, initial_capital: 100_000 },
      { name: "查理·芒格", description: munger_desc, risk_level: :balanced, initial_capital: 100_000 },
      { name: "彼得·林奇", description: lynch_desc, risk_level: :balanced, initial_capital: 100_000 },
      { name: "乔治·索罗斯", description: soros_desc, risk_level: :aggressive, initial_capital: 100_000 },
      { name: "雷·达里奥", description: dalio_desc, risk_level: :balanced, initial_capital: 100_000 },
      { name: "本杰明·格雷厄姆", description: graham_desc, risk_level: :conservative, initial_capital: 100_000 }
    ]
  end

  def create_trader(user, trader_info)
    existing = user.traders.find_by(name: trader_info[:name])
    if existing
      puts "Trader '#{trader_info[:name]}' already exists, skipping..."
      return existing
    end

    user.traders.create!(
      name: trader_info[:name],
      description: trader_info[:description],
      risk_level: trader_info[:risk_level],
      initial_capital: trader_info[:initial_capital],
      status: :active
    )
  rescue => e
    puts "Failed to create trader '#{trader_info[:name]}': #{e.message}"
    nil
  end

  def generate_strategies(trader)
    return if trader.trading_strategies.present?
    puts "  Generating strategies for #{trader.name}..."

    sleep 2
    service = StrategyGeneratorService.new(trader.description, risk_level: trader.risk_level)
    strategies = service.generate_strategies

    strategies.each do |strategy_params|
      trader.trading_strategies.create!(strategy_params)
      source = strategy_params[:generated_by] || :matrix
      puts "    - [#{source.to_s.upcase}] #{strategy_params[:market_condition]}: #{strategy_params[:name]}"
    end
  rescue => e
    puts "  ERROR: Failed to generate strategies for #{trader.name}: #{e.message}"
    raise
  end
end
