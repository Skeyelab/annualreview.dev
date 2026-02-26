class EvidenceNormalizer
  def self.normalize(raw, start_date = nil, end_date = nil)
    new(raw, start_date, end_date).normalize
  end

  def initialize(raw, start_date, end_date)
    @raw = raw.deep_symbolize_keys
    @start_date = start_date
    @end_date = end_date
  end

  def normalize
    contributions = []
    pr_numbers_by_repo = Set.new

    raw_prs.each do |pr|
      repo = pr.dig(:base, :repo, :full_name) || pr.dig(:head, :repo, :full_name) || @raw[:repo] || ""
      date = pr[:merged_at] || pr[:created_at] || pr[:updated_at]
      next unless in_range?(date)
      pr_numbers_by_repo.add("#{repo}##{pr[:number]}")
      contributions << normalize_pr(pr, repo)
    end

    raw_reviews.each do |r|
      repo = r.dig(:repository, :full_name) || r[:repo] || @raw[:repo] || ""
      pull_number = r[:pull_request_url]&.split("/")&.last || r[:pull_number]
      date = r[:submitted_at] || r[:created_at]
      next unless in_range?(date)
      contributions << normalize_review(r, repo, pull_number || "")
    end

    raw_releases.each do |rel|
      repo = rel.dig(:repository, :full_name) || @raw[:repo] || ""
      date = rel[:published_at] || rel[:created_at]
      next unless in_range?(date)
      contributions << normalize_release(rel, repo)
    end

    commit_sha_to_pr = Set.new
    raw_prs.each do |pr|
      (pr[:commits] || []).each do |c|
        sha = c.is_a?(String) ? c : (c[:sha] || c.dig(:commit, :sha))
        commit_sha_to_pr.add(sha) if sha
      end
    end

    raw_commits.each do |c|
      sha = c[:sha] || c.dig(:commit, :sha)
      repo = c.dig(:repository, :full_name) || @raw[:repo] || ""
      date = c.dig(:commit, :author, :date) || c.dig(:commit, :committer, :date) || c.dig(:author, :date)
      next unless in_range?(date)
      next if sha && commit_sha_to_pr.include?(sha)
      contributions << normalize_commit(c, repo, sha)
    end

    sd = @start_date || @raw.dig(:timeframe, :start_date) || "2020-01-01"
    ed = @end_date || @raw.dig(:timeframe, :end_date) || Date.today.iso8601
    { timeframe: { start_date: sd, end_date: ed }, role_context_optional: @raw[:role_context_optional], contributions: contributions }
  end

  private

  def raw_prs = @raw[:pull_requests] || @raw[:pulls] || @raw[:pull_requests_list] || []
  def raw_reviews = @raw[:reviews] || []
  def raw_releases = @raw[:releases] || []
  def raw_commits = @raw[:commits] || []

  def in_range?(date_str)
    return true unless @start_date || @end_date
    return false unless date_str
    begin
      d = Time.parse(date_str)
    rescue ArgumentError
      return false
    end
    return false if @start_date && d < Time.parse(@start_date)
    return false if @end_date && d > Time.parse(@end_date) + 86400
    true
  end

  def contribution_id(repo, _type, number_or_sha)
    slug = (repo || "").sub(%r{/$}, "")
    slug.empty? ? "##{number_or_sha}" : "#{slug}##{number_or_sha}"
  end

  def base_contribution
    { id: "", type: "pull_request", title: "", url: "", repo: "",
      merged_at: nil, labels: [], files_changed: 0, additions: 0, deletions: 0,
      summary: "", body: "", linked_issues: [], review_comments_count: 0, approvals_count: 0 }
  end

  def normalize_pr(pr, repo)
    labels = (pr[:labels] || []).map { |l| l.is_a?(String) ? l : (l[:name] || "") }
    base_contribution.merge(
      id: contribution_id(repo, "pull_request", pr[:number]),
      type: "pull_request",
      title: pr[:title] || "",
      url: pr[:html_url] || pr[:url] || "",
      repo: repo,
      merged_at: pr[:merged_at],
      labels: labels,
      files_changed: pr[:changed_files] || 0,
      additions: pr[:additions] || 0,
      deletions: pr[:deletions] || 0,
      summary: (pr[:body] || "")[0, 500],
      body: pr[:body] || "",
      review_comments_count: pr[:review_comments] || 0
    )
  end

  def normalize_review(review, repo, pull_number)
    base_contribution.merge(
      id: contribution_id(repo, "review", "#{pull_number}-#{review[:id]}"),
      type: "review",
      title: "Review: #{(review[:body] || "")[0, 60]}",
      url: review[:html_url] || review[:url] || "",
      repo: repo,
      summary: (review[:body] || "")[0, 500],
      body: review[:body] || "",
      approvals_count: review[:state] == "APPROVED" ? 1 : 0
    )
  end

  def normalize_release(rel, repo)
    base_contribution.merge(
      id: contribution_id(repo, "release", rel[:id] || rel[:tag_name] || ""),
      type: "release",
      title: rel[:name] || rel[:tag_name] || "Release",
      url: rel[:html_url] || rel[:url] || "",
      repo: repo,
      merged_at: rel[:published_at] || rel[:created_at],
      summary: (rel[:body] || "")[0, 500],
      body: rel[:body] || ""
    )
  end

  def normalize_commit(commit, repo, sha)
    inner = commit[:commit] || commit
    date = commit.dig(:author, :date) || inner.dig(:committer, :date) || inner.dig(:author, :date)
    msg = inner[:message] || commit[:message] || ""
    base_contribution.merge(
      id: contribution_id(repo, "issue", (sha || "")[0, 7]),
      type: "issue",
      title: msg.split("\n").first&.slice(0, 200) || sha&.slice(0, 7) || "",
      url: commit[:html_url] || "https://github.com/#{repo}/commit/#{sha}",
      repo: repo,
      merged_at: date,
      summary: msg[0, 500],
      body: msg
    )
  end
end
