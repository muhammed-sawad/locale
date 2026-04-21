flowchart LR
    A[Client] --> B[GET /service-requests]

    B --> C[Fetch ServiceRequest]
    B --> D[Authorization Check]

    B --> E[RadiologyServiceRequest Table]

    E --> F[Extract dicom_study_uid]

    B --> G[ThreadPoolExecutor]

    G --> H[fetch_study]

    H --> I[Cache Lookup]
    I -->|Hit| J[Return Cached]

    I -->|Miss| K[d_query_study]
    K --> L[/rs/studies]

    L --> M[d_query_series]
    M --> N[/series]

    N --> O[d_find]
    K --> O

    O --> P[d_datetime_to_iso]
    P --> Q[Build Object]
    Q --> R[Cache Store]
    R --> S[Return Result]

    G --> T[as_completed]
    T --> U[future.result()]
    U --> V[Append results]

    V --> W[Final Response]
    W --> A
