# **Project Proposal: Peer-to-Peer Academic Support Network**

# **1\. Executive Summary**

The prevailing model in Ugandan universities is one of "attend lectures and fight for your life." Students facing academic roadblocks often struggle in silence due to the intimidation of large class sizes and a lack of micro-intervention safety nets. This document outlines the system analysis and design for a Peer-to-Peer Academic Support Network—a localized, dynamic platform designed to match struggling students with qualified peer tutors, effectively addressing the systemic issue of high retake rates and academic drop-off.

# **2\. Problem Definition**

- **The "One-to-Many" Trap:** Current university infrastructure relies on massive lectures. Learning Management Systems (LMS) act merely as static repositories rather than active learning environments.
- **The Silent Struggle:** Intimidation and imposter syndrome prevent students from seeking help from lecturers. Consequently, a minor misunderstanding in a foundational concept spirals into a guaranteed retake.
- **Systemic Inefficiency:** High retake rates crowd lecture halls, strain limited university resources, and ultimately produce graduates with fundamental knowledge gaps, negatively impacting the national workforce. Existing solutions like faculty association review sessions are too broad and fail to address specific, individual learning roadblocks.

# **3\. Stakeholder Analysis**

| Stakeholder Group          | Role & Impact                   | Primary Requirements                                                                     |
| :------------------------- | :------------------------------ | :--------------------------------------------------------------------------------------- |
| **Primary Users**          | Struggling Students             | Immediate, frictionless, and stigma-free assistance on hyper-specific concepts.          |
| **Secondary Users**        | Peer Tutors                     | Verifiable extracurricular assets, leadership experience, and knowledge consolidation.   |
| **Tertiary Beneficiaries** | University Administration       | Reduced administrative overhead, improved graduation rates, and better academic metrics. |
| **Sponsors**               | Institutions/Corporate Partners | Targeted faculty sponsorship to guarantee a higher quality of graduates.                 |

# **4\. System Analysis & Proposed Solution**

Instead of a B2C model where students pay (which is unfeasible given student purchasing power), the system will operate on an incentive-based or B2B model where the institution or corporate sponsors back the platform.

## **4.1 System Capabilities**

- **Targeted Matching Engine:** Connects a student's specific topic request (e.g., "Matrix Transformations" or "Database Normalization") with a peer tutor who has demonstrated verified competency in that exact area.
- **Incentivization Tracking:** Logs peer tutoring hours to generate verified "Teaching Assistant" certificates and leadership credits.
- **Frictionless Scheduling:** In-app coordination for brief, focused, one-on-one micro-interventions.

## **4.2 System Requirements**

**Functional Requirements**

- User authentication using File (SSO integration with university credentials).
- Profile creation featuring Tutor vs. Tutee roles and subject competency mapping.
- Request broadcasting and real-time matching algorithm.
- Session logging and feedback/rating loop for quality assurance.

**Non-Functional Requirements**

- **Accessibility:** Mobile-first design optimized for low-bandwidth environments.
- **Privacy:** Secure academic record handling and data privacy compliance.
- **Performance:** Low latency for real-time request matching and notification delivery.

## **4.3 Tutor Validation & Quality Assurance Protocol**

A peer-to-peer matching platform is only effective if the supply side (tutors) is highly competent. To maintain academic integrity without introducing prohibitive friction, the system employs a multi-tiered validation engine.  
**Tier 1: Academic Data Integration (The Hard Gate)**

- **Mechanism:** Users upload their university portal transcript, or the backend queries the university\&apos;s academic database via a secure endpoint.
- **Logic:** A student cannot register to tutor a specific course unit unless verified to have scored a minimum of a B+ or A in that module.

**Tier 2: External Portfolio Verification (The Practical Gate)**

- **Mechanism:** Tutors can link verifiable external proof of competence (e.g., GitHub API integration for software engineering modules, or active project deployments).
- **Logic:** Allows provisional overrides for practical skills if a student\&apos;s project portfolio demonstrates exceptional proficiency beyond traditional grading.

**Tier 3: The Probationary Feedback Loop (The Community Gate)**

- **Mechanism:** Newly verified tutors start with a “Provisional” badge. Their initial sessions are strictly monitored via mandatory post-session ratings from tutees.
- **Logic:** High average ratings unlock the “Verified Tutor” status and leadership credits. Ratings below a set threshold automatically downgrade or revoke matching priority.

**Database Architecture for Validation:**  
To support this logic, the relational database (PostgreSQL) incorporates specific structures:

- **Users Table:** Tracks _role\_type_ (tutee, provisional\_tutor, verified\_tutor) to control access levels.
- **Course\_Units Table:** Maps the exact university curriculum.
- **Competencies Table:** Acts as the validation gate mapping _user\_id_ to _unit\_id_ alongside _grade\_achieved_ and _verification\_status_ (Boolean).
- **Session\_Logs Table:** Feeds the algorithm and feedback loop using _rating_ and _feedback\_text_ to continuously monitor quality.

## **4.4 Regulatory & Legal Compliance Framework**

- **Uganda Data Protection and Privacy Act, 2019 (DPPA):** Handling sensitive academic data (transcripts, grades) requires explicit consent, secure storage, and registration with the Personal Data Protection Office (PDPO).
- **Electronic Transactions Act, 2011:** Outlines the platform\&apos;s liability as a service provider/intermediary.
- **Institutional IT Policies:** Ensuring compliance with the university\&apos;s internal data sharing and network security guidelines, particularly when querying student portals or SSO.

# **5\. Architectural Design Conceptualization**

To ensure feasibility for a Minimum Viable Product (MVP), the proposed architecture is:

- **Frontend Interface:** A cross-platform mobile application built with **Flutter** to ensure maximum adoption among a mobile-first student demographic.
- **Backend & API:** A lightweight, high-performance RESTful API using **FastAPI (Python)** to handle the routing and matching logic.
- **Database Management:** A **PostgreSQL** relational database to manage complex user relationships, course unit mapping, and session logs.

# **6\. Pilot Phase Roadmap (12-Week Implementation but could be shorter depending on the deadline)**

These phases will begin immediately after the MVP has been built to make sure it is feasible and is able to solve an actual problem affecting the students and the education system.

- **Phase 1: Pre-Pilot Legal & Institutional Alignment (Weeks 1-3).** Focus on securing faculty buy-in, finalizing data compliance, and vetting the first batch of 10-20 peer tutors.
- **Phase 2: Closed Beta / The "Sandbox" (Weeks 4-6).** Launching the MVP to a single high-failure-rate course unit (e.g., in the Computer Science department). Focus on testing the matching algorithm and feedback loop.
- **Phase 3: Controlled Inter-Faculty Rollout (Weeks 7-10).** Expanding to 3-5 courses across different faculties to test cross-disciplinary scalability.
- **Phase 4: Post-Pilot Evaluation (Weeks 11-12).** Aggregating session logs, tutor ratings, and impact on continuous assessment scores to present to university administration for official adoption.

# **7\. Conclusion**

Implementing this peer-to-peer network transitions the educational ecosystem from passive institutional neglect to an active, student-driven safety net. By validating the system architecture and stakeholder incentives prior to implementation, we ensure a sustainable and scalable solution to one of the most critical gaps in higher education.

The next stage of development will involve a pilot phase at Place to test the matching engine efficacy.

[Gilbert Asiimwe](mailto:gilbert.asiimwe.dev@gmail.com)  
Lead Systems Architect
