# Chatwoot API Documentation

## Introduction

This document provides an overview of the Chatwoot APIs, their functionalities, and their dependencies. It is intended for developers who need to integrate with or extend Chatwoot.

**Note:** This document provides a structural outline based on an automated scan of the project's controller files. Specific details about each endpoint's functionality, request/response formats, and exact upstream/downstream dependencies need to be filled in by examining the source code.

## 1. Standard APIs (`app/controllers/api/`)

This section covers the standard APIs available in Chatwoot.

### 1.1. Base Controller (`app/controllers/api/base_controller.rb`)

*   **Functionality:** (Describe the base functionality, authentication, and common concerns handled by this controller for other API controllers that inherit from it.)
*   **Upstream Dependencies:** (e.g., Rails framework, specific gems)
*   **Downstream Dependencies:** (Most other API controllers under `app/controllers/api/`)

### 1.2. API v1 (`app/controllers/api/v1/`)

#### 1.2.1. Accounts Controller (`app/controllers/api/v1/accounts_controller.rb`)
*   **Functionality:** (Describe account-related operations like creating, updating, viewing accounts)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 1.2.2. Notification Subscriptions Controller (`app/controllers/api/v1/notification_subscriptions_controller.rb`)
*   **Functionality:** (Describe operations related to managing user notification subscriptions)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 1.2.3. Profiles Controller (`app/controllers/api/v1/profiles_controller.rb`)
*   **Functionality:** (Describe operations related to user profiles, e.g., viewing, updating)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 1.2.4. Webhooks Controller (`app/controllers/api/v1/webhooks_controller.rb`)
*   **Functionality:** (Describe operations related to managing webhooks for integrations)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 1.2.5. Widget API (`app/controllers/api/v1/widget/`)
    *   **(Further list controllers found under `app/controllers/api/v1/widget/` and detail them)**
    *   Example: `contacts_controller.rb`, `messages_controller.rb` etc.
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

#### 1.2.6. Accounts (Scoped) API (`app/controllers/api/v1/accounts/`)
    *   **(Further list controllers found under `app/controllers/api/v1/accounts/` and detail them)**
    *   This likely refers to APIs scoped to a specific account.
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

#### 1.2.7. Integrations API (`app/controllers/api/v1/integrations/`)
    *   **(Further list controllers found under `app/controllers/api/v1/integrations/` and detail them)**
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

### 1.3. API v2 (`app/controllers/api/v2/`)

#### 1.3.1. Accounts Controller (`app/controllers/api/v2/accounts_controller.rb`)
*   **Functionality:** (Describe account-related operations specific to v2, if different from v1 or an evolution)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 1.3.2. Accounts (Scoped) API (`app/controllers/api/v2/accounts/`)
    *   **(Further list controllers found under `app/controllers/api/v2/accounts/` and detail them)**
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

## 2. Public APIs (`app/controllers/public/api/`)

This section covers APIs that are designed for public consumption, often without requiring the same level of authentication as the standard APIs.

### 2.1. Public API v1 (`app/controllers/public/api/v1/`)

#### 2.1.1. CSAT Survey Controller (`app/controllers/public/api/v1/csat_survey_controller.rb`)
*   **Functionality:** (Describe operations related to submitting and possibly retrieving CSAT survey data)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 2.1.2. Inboxes Controller (`app/controllers/public/api/v1/inboxes_controller.rb`)
*   **Functionality:** (Describe public operations related to inboxes, perhaps for widget configuration or status)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 2.1.3. Portals Controller (`app/controllers/public/api/v1/portals_controller.rb`)
*   **Functionality:** (Describe operations related to public-facing portals, e.g., help centers)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 2.1.4. Inboxes (Scoped) API (`app/controllers/public/api/v1/inboxes/`)
    *   **(Further list controllers found under `app/controllers/public/api/v1/inboxes/` and detail them)**
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

#### 2.1.5. Portals (Scoped) API (`app/controllers/public/api/v1/portals/`)
    *   **(Further list controllers found under `app/controllers/public/api/v1/portals/` and detail them)**
    *   **Functionality:**
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

## 3. Platform APIs (`app/controllers/platform/api/`)

This section covers APIs that might be used for platform-level integrations or functionalities, potentially for communication between different services or for administrative tasks.

### 3.1. Platform API v1 (`app/controllers/platform/api/v1/`)

#### 3.1.1. Account Users Controller (`app/controllers/platform/api/v1/account_users_controller.rb`)
*   **Functionality:** (Describe operations related to managing users within an account at a platform level)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 3.1.2. Accounts Controller (`app/controllers/platform/api/v1/accounts_controller.rb`)
*   **Functionality:** (Describe platform-level operations for managing accounts)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 3.1.3. Agent Bots Controller (`app/controllers/platform/api/v1/agent_bots_controller.rb`)
*   **Functionality:** (Describe operations related to managing and interacting with agent bots)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

#### 3.1.4. Users Controller (`app/controllers/platform/api/v1/users_controller.rb`)
*   **Functionality:** (Describe platform-level operations for managing users)
*   **Upstream Dependencies:**
*   **Downstream Dependencies:**

## 4. Enterprise APIs (`enterprise/app/controllers/api/`)

This section covers APIs specific to the Enterprise Edition of Chatwoot.

### 4.1. Enterprise API v1 (`enterprise/app/controllers/api/v1/`)

#### 4.1.1. Accounts (Scoped) API (`enterprise/app/controllers/api/v1/accounts/`)
    *   **(Further list controllers found under `enterprise/app/controllers/api/v1/accounts/` and detail them)**
    *   **Functionality:** (Describe enterprise-specific API functionalities for accounts)
    *   **Upstream Dependencies:**
    *   **Downstream Dependencies:**

## How to Complete This Document

For each controller and its actions (endpoints):

1.  **Identify Endpoints:** List the specific API endpoints defined in the controller (e.g., `GET /api/v1/accounts`, `POST /api/v1/accounts`).
2.  **Describe Functionality:** For each endpoint, clearly explain what it does, its purpose, and any important business logic.
3.  **Request Parameters:** Document required and optional request parameters (path, query, body). Specify data types and validation rules.
4.  **Response Format:** Describe the structure of the JSON response, including data types and example responses for success and error scenarios.
5.  **Authentication & Authorization:** Specify if authentication is required and what roles/permissions are needed to access the endpoint.
6.  **Upstream Dependencies:**
    *   **Internal Services/Models:** Which other services, models, or modules within Chatwoot does this API endpoint call or rely on? (e.g., `Account.find`, `NotificationService.send_notification`).
    *   **External Services:** Does it call any third-party APIs? (e.g., Twilio API, Slack API).
7.  **Downstream Dependencies:**
    *   **Internal Consumers:** Which other parts of the Chatwoot application (e.g., frontend UI components, other backend services, background jobs) call this API endpoint?
    *   **External Consumers:** Are there known third-party integrations or client applications that rely on this endpoint?

Reviewing the Rails routes (`config/routes.rb`) will be crucial for identifying all available endpoints and their paths. Examining the controller action methods will be necessary to determine functionality and dependencies. 