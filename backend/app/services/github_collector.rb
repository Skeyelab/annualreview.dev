class GithubCollector
  GRAPHQL_URL = "https://api.github.com/graphql"
  PAGE_SIZE = 100

  SEARCH_QUERY = <<~GQL
    query($q: String!, $after: String) {
      search(query: $q, type: ISSUE, first: #{PAGE_SIZE}, after: $after) {
        edges {
          node {
            __typename
            ... on PullRequest {
              number title body url mergedAt additions deletions changedFiles
              baseRepository { nameWithOwner }
              labels(first: 100) { nodes { name } }
              reviewThreads(first: 1) { totalCount }
              reviews(first: 100) { nodes { id body state submittedAt url } }
            }
          }
        }
        pageInfo { endCursor hasNextPage }
      }
    }
  GQL

  def initialize(token:, start_date:, end_date:)
    @token = token
    @start_date = start_date
    @end_date = end_date
  end

  def collect_raw
    login = fetch_viewer_login
    prs = []
    reviews = []
    cursor = nil

    q = "author:#{login} type:pr created:#{@start_date}..#{@end_date}"
    loop do
      data = graphql_fetch(SEARCH_QUERY, q: q, after: cursor)
      search = data.dig("search") || break
      edges = search["edges"] || []

      edges.each do |edge|
        node = edge["node"]
        next unless node && node["__typename"] == "PullRequest"

        pr = map_pr(node)
        prs << pr

        (node.dig("reviews", "nodes") || []).each do |r|
          reviews << map_review(r, pr[:base][:repo][:full_name], node["number"])
        end
      end

      break unless search.dig("pageInfo", "hasNextPage")
      cursor = search.dig("pageInfo", "endCursor")
      break unless cursor
    end

    { timeframe: { start_date: @start_date, end_date: @end_date }, pull_requests: prs, reviews: reviews }
  end

  private

  def fetch_viewer_login
    data = graphql_fetch("query { viewer { login } }")
    login = data.dig("viewer", "login")
    raise "Could not get viewer login" unless login
    login
  end

  def graphql_fetch(query, variables = {})
    uri = URI(GRAPHQL_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@token}"
    })
    req.body = { query: query, variables: variables }.to_json
    res = http.request(req)
    raise "#{GRAPHQL_URL} #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    if json["errors"]&.any?
      raise json["errors"].map { |e| e["message"] }.join("; ")
    end
    json["data"]
  end

  def map_pr(node)
    repo = node.dig("baseRepository", "nameWithOwner") || ""
    labels = (node.dig("labels", "nodes") || []).map { |n| { name: n["name"] } }
    {
      number: node["number"],
      title: node["title"] || "",
      body: node["body"] || "",
      url: node["url"] || "",
      html_url: node["url"] || "",
      merged_at: node["mergedAt"],
      base: { repo: { full_name: repo } },
      labels: labels,
      changed_files: node["changedFiles"] || 0,
      additions: node["additions"] || 0,
      deletions: node["deletions"] || 0,
      review_comments: node.dig("reviewThreads", "totalCount") || 0
    }
  end

  def map_review(node, repo, pull_number)
    {
      id: node["id"],
      body: node["body"] || "",
      state: node["state"] || "",
      submitted_at: node["submittedAt"],
      url: node["url"] || "",
      html_url: node["url"] || "",
      repository: { full_name: repo },
      pull_number: pull_number
    }
  end
end
