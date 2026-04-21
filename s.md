```mermaid
flowchart LR
    A[Client Viewer] --> B[GET /studies API]
    B --> C[Authorization Check]
    B --> D[Postgres: DicomStudy]

    B --> E[ThreadPoolExecutor]

    E --> F[Cache Lookup]

    F -->|Hit| G[Return Cached Study]
    F -->|Miss| H[QIDO: /rs/studies]
    F -->|Miss| I[QIDO: /series]

    H --> J[d_find Extraction]
    I --> J

    J --> K[Datetime Conversion]
    K --> L[Cache Store]

    E --> M[Aggregate Results]
    M --> A
