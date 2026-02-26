class GenerateJob < ApplicationJob
  queue_as :default

  def perform(review_year_id)
    ry = ReviewYear.find(review_year_id)
    result = ReviewPipeline.new(ry.evidence, api_key: ENV["OPENAI_API_KEY"]).run
    ry.update!(pipeline_result: result, pipeline_result_at: Time.current)
  end
end
