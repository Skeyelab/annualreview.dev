class MarkdownGenerator
  def self.generate(data, timeframe: nil, goals: nil)
    new(data, timeframe:, goals:).generate
  end

  def initialize(data, timeframe: nil, goals: nil)
    @data = data.deep_symbolize_keys
    @timeframe = timeframe&.deep_symbolize_keys
    @goals = goals
  end

  def generate
    lines = []

    lines << "# Annual Review Report"
    if @timeframe && @timeframe[:start_date] && @timeframe[:end_date]
      lines << "*#{@timeframe[:start_date]} – #{@timeframe[:end_date]}*"
    end
    lines << ""

    goals_trimmed = @goals&.strip
    if goals_trimmed.present?
      lines.push("---", "", "## Goals", "", goals_trimmed, "")
    end

    summary = @data.dig(:self_eval, :sections, :summary)
    if summary && summary[:text].present?
      lines.push("---", "", "## Summary", "", summary[:text])
      lines << "*Sources: #{evidence_links(summary[:evidence])}*" if summary[:evidence]&.any?
      lines << ""
    end

    theme_list = @data.dig(:themes, :themes) || []
    if theme_list.any?
      lines.push("---", "", "## Themes", "")
      theme_list.each_with_index do |t, i|
        lines << "### #{i + 1}. #{t[:theme_name]}"
        lines.push("", "> #{t[:one_liner]}") if t[:one_liner]
        lines.push("", "**Why it matters:** #{t[:why_it_matters]}") if t[:why_it_matters]
        lines.push("", "*Confidence: #{t[:confidence]}*") if t[:confidence]
        lines.push("", "*Notes: #{t[:notes_or_assumptions]}*") if t[:notes_or_assumptions]
        if t[:anchor_evidence]&.any?
          links = t[:anchor_evidence].map { |e| "[#{e[:title] || e[:id]}](#{e[:url]})" }.join(", ")
          lines.push("", "*Evidence: #{links}*")
        end
        lines << ""
      end
    end

    top10 = @data.dig(:bullets, :top_10_bullets_overall) || []
    by_theme = @data.dig(:bullets, :bullets_by_theme) || []
    if top10.any? || by_theme.any?
      lines.push("---", "", "## Impact Bullets", "")
      if top10.any?
        lines.push("### Top 10 Bullets", "")
        top10.each { |b| lines << "- #{b[:text]}#{refs(b[:evidence])}" }
        lines << ""
      end
      if by_theme.any?
        theme_name_map = theme_list.each_with_object({}) { |t, h| h[t[:theme_id]] = t[:theme_name] }
        by_theme.each do |bt|
          name = theme_name_map[bt[:theme_id]] || bt[:theme_id]
          lines.push("### #{name}", "")
          (bt[:bullets] || []).each { |b| lines << "- #{b[:text]}#{refs(b[:evidence])}" }
          lines << ""
        end
      end
    end

    story_list = @data.dig(:stories, :stories) || []
    if story_list.any?
      lines.push("---", "", "## STAR Stories", "")
      story_list.each do |s|
        lines << "### #{s[:title]}"
        lines.push("", "**Situation:** #{s[:situation]}") if s[:situation]
        lines.push("", "**Task:** #{s[:task]}") if s[:task]
        if s[:actions]&.any?
          lines.push("", "**Actions:**")
          s[:actions].each { |a| lines << "- #{a}" }
        end
        if s[:results]&.any?
          lines.push("", "**Results:**")
          s[:results].each { |r| lines << "- #{r}" }
        end
        if s[:evidence]&.any?
          links = s[:evidence].map { |e| "[#{e[:title] || e[:id]}](#{e[:url]})" }.join(", ")
          lines.push("", "*Evidence: #{links}*")
        end
        lines.push("", "*Confidence: #{s[:confidence]}*") if s[:confidence]
        lines << ""
      end
    end

    sections = @data.dig(:self_eval, :sections) || {}
    has_any = sections[:summary] || sections[:key_accomplishments]&.any? ||
              sections[:how_i_worked] || sections[:growth] || sections[:next_year_goals]&.any?

    if has_any
      lines.push("---", "", "## Self-Evaluation", "")
      if sections[:key_accomplishments]&.any?
        lines.push("### Key Accomplishments", "")
        sections[:key_accomplishments].each { |item| lines << "- #{item[:text]}#{refs(item[:evidence])}" }
        lines << ""
      end
      if sections[:how_i_worked] && sections[:how_i_worked][:text].present?
        lines.push("### How I Worked", "", sections[:how_i_worked][:text])
        lines << "*Sources: #{evidence_links(sections[:how_i_worked][:evidence])}*" if sections[:how_i_worked][:evidence]&.any?
        lines << ""
      end
      if sections[:growth] && sections[:growth][:text].present?
        lines.push("### Growth", "", sections[:growth][:text])
        lines << "*Sources: #{evidence_links(sections[:growth][:evidence])}*" if sections[:growth][:evidence]&.any?
        lines << ""
      end
      if sections[:next_year_goals]&.any?
        lines.push("### Next Year Goals", "")
        sections[:next_year_goals].each { |g| lines << "- #{g[:text]}#{refs(g[:evidence])}" }
        lines << ""
      end
    end

    all_evidence = collect_all_evidence(theme_list, top10, by_theme, story_list, sections, summary)
    if all_evidence.any?
      lines.push("---", "", "## Evidence Appendix", "")
      lines << "| ID | Title | URL |"
      lines << "|----|-------|-----|"
      all_evidence.each do |e|
        title = (e[:title] || "").gsub("|", "\\|")
        lines << "| #{e[:id] || ""} | #{title} | #{e[:url] || ""} |"
      end
      lines << ""
    end

    lines.join("\n")
  end

  private

  def evidence_links(evidence)
    (evidence || []).map { |e| "[#{e[:id] || e[:title] || "ref"}](#{e[:url]})" }.join(", ")
  end

  def refs(evidence)
    return "" unless evidence&.any?
    " (#{evidence_links(evidence)})"
  end

  def collect_all_evidence(theme_list, top10, by_theme, story_list, sections, summary)
    seen = Set.new
    all = []
    add = ->(ev) {
      (ev || []).each do |e|
        key = e[:url] || e[:id]
        next unless key && !seen.include?(key)
        seen.add(key)
        all << e
      end
    }
    add.call(summary&.dig(:evidence))
    theme_list.each { |t| add.call(t[:anchor_evidence]) }
    top10.each { |b| add.call(b[:evidence]) }
    by_theme.each { |bt| (bt[:bullets] || []).each { |b| add.call(b[:evidence]) } }
    story_list.each { |s| add.call(s[:evidence]) }
    (sections[:key_accomplishments] || []).each { |i| add.call(i[:evidence]) }
    add.call(sections.dig(:how_i_worked, :evidence))
    add.call(sections.dig(:growth, :evidence))
    (sections[:next_year_goals] || []).each { |i| add.call(i[:evidence]) }
    all
  end
end
