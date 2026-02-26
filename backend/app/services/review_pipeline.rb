class ReviewPipeline
  OPENAI_URL = "https://api.openai.com/v1/chat/completions"
  PROMPTS_DIR = Rails.root.join("..", "prompts")

  STEPS = [
    { key: :themes,    prompt_file: "10_theme_cluster.md" },
    { key: :bullets,   prompt_file: "20_impact_bullets.md" },
    { key: :stories,   prompt_file: "30_star_stories.md" },
    { key: :self_eval, prompt_file: "40_self_eval_sections.md" }
  ].freeze

  def initialize(evidence, api_key: nil, model: "gpt-4o-mini", on_progress: nil)
    @evidence = evidence.deep_symbolize_keys
    @api_key = api_key || ENV["OPENAI_API_KEY"]
    @model = model
    @on_progress = on_progress
  end

  def run
    raise "OPENAI_API_KEY required" unless @api_key

    system_prompt = load_prompt("00_system.md")
    results = {}

    STEPS.each_with_index do |step, i|
      @on_progress&.call(step_index: i + 1, total: STEPS.length, step: step[:key])

      input = build_input(step[:key], results)
      prompt_content = load_prompt(step[:prompt_file])
      user_content = "#{prompt_content}\n\nINPUT JSON:\n#{input}"

      response = chat_completion(system_prompt, user_content)
      results[step[:key]] = extract_json(response)
    end

    results
  end

  private

  def load_prompt(name)
    File.read(PROMPTS_DIR.join(name)).strip
  end

  def build_input(step_key, prev)
    case step_key
    when :themes
      { timeframe: @evidence[:timeframe],
        role_context_optional: @evidence[:role_context_optional],
        goals: @evidence[:goals],
        contributions: @evidence[:contributions] }.to_json
    when :bullets
      slimmed = slim_contributions(@evidence[:contributions], body_chars: 400, summary_chars: 500)
      { timeframe: @evidence[:timeframe], goals: @evidence[:goals],
        themes: prev[:themes], contributions: slimmed }.to_json
    when :stories
      ids = collect_evidence_ids(prev[:themes], prev[:bullets])
      contribs = contributions_for_payload(ids, body_chars: 300, summary_chars: 400)
      { timeframe: @evidence[:timeframe], goals: @evidence[:goals],
        themes: prev[:themes],
        bullets_by_theme: prev[:bullets]&.dig("bullets_by_theme"),
        contributions: contribs }.to_json
    when :self_eval
      ids = collect_evidence_ids(prev[:themes], prev[:bullets], prev[:stories])
      contribs = contributions_for_payload(ids, minimal: true)
      { timeframe: @evidence[:timeframe], goals: @evidence[:goals],
        role_context_optional: @evidence[:role_context_optional],
        themes: prev[:themes],
        top_10_bullets_overall: prev[:bullets]&.dig("top_10_bullets_overall") || [],
        stories: prev[:stories]&.dig("stories") || [],
        contributions: contribs }.to_json
    end
  end

  def chat_completion(system_prompt, user_content)
    uri = URI(OPENAI_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120
    req = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    })
    req.body = {
      model: @model,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_content }
      ]
    }.to_json
    res = http.request(req)
    raise "OpenAI #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body).dig("choices", 0, "message", "content") || "{}"
  end

  def extract_json(text)
    start_idx = text.index("{")
    end_idx = text.rindex("}")
    raise "No JSON object in response" unless start_idx && end_idx
    JSON.parse(text[start_idx..end_idx])
  end

  SLIM_KEYS = %w[id type title url repo merged_at labels files_changed additions deletions linked_issues review_comments_count approvals_count].freeze
  MINIMAL_KEYS = %w[id type title url repo merged_at].freeze

  def slim_contributions(contributions, body_chars: 400, summary_chars: 500, minimal: false)
    keys = minimal ? MINIMAL_KEYS : SLIM_KEYS
    (contributions || []).map do |c|
      c = c.stringify_keys
      out = keys.each_with_object({}) { |k, h| h[k] = c[k] if c.key?(k) }
      sum_len = minimal ? 200 : summary_chars
      out["summary"] = c["summary"].to_s[0, sum_len] if c.key?("summary")
      out["body_preview"] = c["body"].to_s[0, body_chars] if !minimal && c.key?("body") && body_chars > 0
      out
    end
  end

  def collect_evidence_ids(themes, bullets, stories = nil)
    ids = Set.new
    (themes&.dig("themes") || []).each do |t|
      (t["evidence_ids"] || []).each { |id| ids.add(id) }
      (t["anchor_evidence"] || []).each { |a| ids.add(a["id"]) if a["id"] }
    end
    (bullets&.dig("bullets_by_theme") || []).each do |g|
      (g["bullets"] || []).each { |b| (b["evidence"] || []).each { |e| ids.add(e["id"]) if e["id"] } }
    end
    (stories&.dig("stories") || []).each do |s|
      (s["evidence"] || []).each { |e| ids.add(e["id"]) if e["id"] }
    end
    ids
  end

  def contributions_for_payload(id_set, **opts)
    contribs = @evidence[:contributions] || []
    by_id = contribs.each_with_object({}) { |c, h| h[c[:id] || c["id"]] = c }
    subset = if id_set.any?
      id_set.filter_map { |id| by_id[id] }
    else
      contribs
    end
    slim_contributions(subset, **opts)
  end
end
