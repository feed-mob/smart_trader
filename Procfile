# Procfile for managing SmartTrader processes
# Use with: gem install foreman
# Then run: foreman start

# Rails web server
web: bundle exec puma -C config/puma.rb

# Sidekiq background job processor
worker: bundle exec sidekiq -C config/sidekiq.yml

# Alternative: Start both with individual processes
# Uncomment to run separately:
# sidekiq: bundle exec sidekiq -r ./config/sidekiq.yml
