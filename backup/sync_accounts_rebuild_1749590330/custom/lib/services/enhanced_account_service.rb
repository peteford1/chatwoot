# Enhanced Account Service
# Created: 2025-06-10 08:40:00 PDT
# Purpose: Extended account management functionality without modifying core Chatwoot

class EnhancedAccountService
  include CustomUtilities::Logger
  
  def initialize(platform_token = nil)
    @platform_token = platform_token || ENV['PLATFORM_API_TOKEN']
    @api_base_url = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  end

  # Get accounts with enhanced filtering
  def get_accounts_with_filter(filter_options = {})
    log_info "Fetching accounts with filter: #{filter_options}"
    
    accounts = fetch_all_accounts
    return [] unless accounts

    filtered_accounts = accounts.select do |account|
      matches_filter?(account, filter_options)
    end

    log_info "Found #{filtered_accounts.size} accounts matching filter"
    filtered_accounts
  end

  # Find duplicate accounts based on name patterns
  def find_duplicate_accounts
    log_info "Searching for duplicate accounts"
    
    accounts = fetch_all_accounts
    return [] unless accounts

    duplicates = []
    
    # Group by similar names
    name_groups = accounts.group_by do |account|
      normalize_account_name(account['name'])
    end

    name_groups.each do |normalized_name, group_accounts|
      if group_accounts.size > 1
        duplicates.concat(group_accounts[1..-1]) # Keep first, mark rest as duplicates
      end
    end

    # Find timestamp-based duplicates
    timestamp_duplicates = accounts.select do |account|
      account['name'].match?(/\d{10,}/) # Contains timestamp
    end

    duplicates.concat(timestamp_duplicates)
    duplicates.uniq { |acc| acc['id'] }
  end

  # Get account statistics
  def get_account_statistics
    accounts = fetch_all_accounts
    return {} unless accounts

    stats = {
      total_accounts: accounts.size,
      active_accounts: accounts.count { |acc| acc['status'] == 'active' },
      accounts_by_store: {},
      duplicate_count: find_duplicate_accounts.size,
      legitimate_accounts: get_legitimate_accounts.size
    }

    # Group by store_id in custom_attributes
    accounts.each do |account|
      store_id = account.dig('custom_attributes', 'store_id') || 'unassigned'
      stats[:accounts_by_store][store_id] ||= 0
      stats[:accounts_by_store][store_id] += 1
    end

    log_info "Account statistics generated: #{stats}"
    stats
  end

  # Get legitimate accounts (non-duplicates)
  def get_legitimate_accounts
    all_accounts = fetch_all_accounts
    return [] unless all_accounts

    duplicate_ids = find_duplicate_accounts.map { |acc| acc['id'] }
    
    legitimate = all_accounts.reject do |account|
      duplicate_ids.include?(account['id'])
    end

    log_info "Found #{legitimate.size} legitimate accounts"
    legitimate
  end

  # Enhanced account creation with validation
  def create_account_with_validation(account_params)
    log_info "Creating account with validation: #{account_params['name']}"

    # Check for existing similar accounts
    existing = find_similar_accounts(account_params['name'])
    if existing.any?
      log_warn "Similar accounts found: #{existing.map { |acc| acc['name'] }}"
      return { error: 'Similar account already exists', similar_accounts: existing }
    end

    # Create account via Platform API
    result = create_account_via_api(account_params)
    
    if result && result['id']
      log_info "Account created successfully: ID #{result['id']}"
      { success: true, account: result }
    else
      log_error "Failed to create account: #{result}"
      { error: 'Failed to create account', details: result }
    end
  end

  private

  def fetch_all_accounts
    make_api_request('/platform/api/v1/accounts')
  end

  def make_api_request(endpoint, method = 'GET', body = nil)
    uri = URI("#{@api_base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = case method
              when 'GET'
                Net::HTTP::Get.new(uri)
              when 'POST'
                Net::HTTP::Post.new(uri)
              else
                raise "Unsupported method: #{method}"
              end
    
    request['api_access_token'] = @platform_token
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body
    
    response = http.request(request)
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      JSON.parse(response.body) rescue response.body
    else
      log_error "API Error: #{response.code} - #{response.body}"
      nil
    end
  end

  def matches_filter?(account, filter_options)
    return true if filter_options.empty?

    filter_options.all? do |key, value|
      case key.to_s
      when 'status'
        account['status'] == value
      when 'store_id'
        account.dig('custom_attributes', 'store_id') == value
      when 'name_pattern'
        account['name'].match?(Regexp.new(value, Regexp::IGNORECASE))
      when 'created_after'
        account['created_at'] && Date.parse(account['created_at']) > Date.parse(value)
      else
        account[key.to_s] == value
      end
    end
  end

  def normalize_account_name(name)
    # Remove timestamps, extra spaces, and common variations
    normalized = name.gsub(/\d{10,}/, '') # Remove timestamps
                     .gsub(/\s+/, ' ')     # Normalize spaces
                     .strip
                     .downcase
    
    # Remove common test prefixes/suffixes
    normalized.gsub(/^(test|demo|sample)\s*/, '')
              .gsub(/\s*(test|demo|sample)$/, '')
  end

  def find_similar_accounts(name)
    accounts = fetch_all_accounts
    return [] unless accounts

    normalized_target = normalize_account_name(name)
    
    accounts.select do |account|
      normalized_existing = normalize_account_name(account['name'])
      # Consider similar if normalized names match or are very close
      normalized_existing == normalized_target ||
        string_similarity(normalized_existing, normalized_target) > 0.8
    end
  end

  def string_similarity(str1, str2)
    # Simple similarity calculation (could be enhanced with more sophisticated algorithms)
    return 1.0 if str1 == str2
    return 0.0 if str1.empty? || str2.empty?
    
    longer = str1.length > str2.length ? str1 : str2
    shorter = str1.length > str2.length ? str2 : str1
    
    return 0.0 if longer.empty?
    
    (longer.length - levenshtein_distance(longer, shorter)) / longer.length.to_f
  end

  def levenshtein_distance(str1, str2)
    # Simple Levenshtein distance implementation
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }
    
    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }
    
    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,     # deletion
          matrix[i][j - 1] + 1,     # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end
    
    matrix[str1.length][str2.length]
  end

  def create_account_via_api(account_params)
    make_api_request('/platform/api/v1/accounts', 'POST', account_params)
  end
end 