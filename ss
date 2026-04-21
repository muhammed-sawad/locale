# DICOM Studies via ServiceRequest – Workflow Documentation

## 1. Overview

This API retrieves **DICOM studies linked to a specific ServiceRequest**.

Unlike the patient-based API, this uses a **mapping table (`RadiologyServiceRequest`)** to connect:

```text
ServiceRequest → RadiologyServiceRequest → DicomStudy → DICOM Server
```

---

## 2. API Endpoint

```
GET /service-requests?serviceRequestId=<external_id>
```

### Input

* `serviceRequestId`: External ID of the ServiceRequest

### Output

* List of study objects (same structure as `fetch_study`)
* May contain `null` entries (no filtering applied)

---

## 3. Data Model Relationships

### Core Tables

#### ServiceRequest

* Primary clinical entity

#### RadiologyServiceRequest

* Mapping table between:

  * ServiceRequest
  * DicomStudy

#### DicomStudy

* Stores:

  * `dicom_study_uid` (StudyInstanceUID)

---

### Relationship Flow

```text
ServiceRequest (1)
    ↓
RadiologyServiceRequest (many)
    ↓
DicomStudy (many)
    ↓
dicom_study_uid
```

---

## 4. End-to-End Workflow

### Step 1: Request Received

```python
service_request_external_id = request.query_params.get("serviceRequestId")
```

---

### Step 2: Fetch ServiceRequest

```python
service_request = ServiceRequest.objects.get(
    external_id=service_request_external_id
)
```

---

### Step 3: Authorization Check

```python
AuthorizationController.call(
    "can_write_service_request",
    self.request.user,
    service_request
)
```

* Requires **write permission** (even for GET)

---

### Step 4: Fetch RadiologyServiceRequest Records

```python
tsr = RadiologyServiceRequest.objects.filter(
    service_request__external_id=service_request_external_id,
    dicom_study__dicom_study_uid__isnull=False,
)
```

This ensures:

* Only mappings with valid study UID are used

---

### Step 5: Extract Study UIDs

```python
r.dicom_study.dicom_study_uid
```

---

### Step 6: Parallel Execution

```python
executor.submit(fetch_study, study_uid)
```

* Uses `ThreadPoolExecutor(max_workers=10)`
* Each study processed independently

---

### Step 7: Result Aggregation (`as_completed`)

```python
for future in as_completed(future_to_study):
    results.append(future.result())
```

#### Behavior

* Waits for futures to complete
* Returns results in **completion order**
* No filtering → `None` may be included

---

### Step 8: Response

```python
return Response(results)
```

---

## 5. Internal Processing (`fetch_study`)

This API reuses the same pipeline:

```text
Cache Lookup
    ↓
d_query_study (QIDO-RS)
    ↓
d_query_series_for_study
    ↓
d_find (tag extraction)
    ↓
d_datetime_to_iso
    ↓
Build response object
    ↓
Cache Store
    ↓
Return
```

---

## 6. Concurrency Model

### Execution

```text
Main Thread:
    submit tasks → collect futures

Worker Threads:
    execute fetch_study()

Aggregator:
    as_completed() → result collection
```

---

### as_completed Flow

```text
Submit Futures
    ↓
Wait for any to complete
    ↓
Yield finished future
    ↓
Call future.result()
    ↓
Append to results
    ↓
Repeat until done
```

---

## 7. Sequence Diagram (Developer-Friendly)

```text
Client → API: GET /service-requests?serviceRequestId=123

API → DB: Fetch ServiceRequest  
API → Auth: Check permission  

API → DB: Fetch RadiologyServiceRequest  

loop each mapping (parallel)
    API → Cache: Check study cache  

    alt Cache Hit
        Cache → API: Return study  

    else Cache Miss
        API → DICOM: GET /rs/studies  
        API → DICOM: GET /rs/studies/{uid}/series  

        API → API: Extract tags (d_find)  
        API → API: Convert datetime  
        API → Cache: Store result  
    end
end

API → API: as_completed() aggregation  
API → Client: Return results  
```

---

## 8. Key Differences from Patient-Based API

| Aspect      | Patient API         | ServiceRequest API                 |
| ----------- | ------------------- | ---------------------------------- |
| Entry point | Patient             | ServiceRequest                     |
| Mapping     | Direct (DicomStudy) | Indirect (RadiologyServiceRequest) |
| Filtering   | Skips None          | Includes None                      |
| Use case    | All patient studies | Studies tied to a request          |

---

## 9. Important Observations

### 1. No Filtering of None

```python
results.append(future.result())
```

* `None` values can appear in response

---

### 2. No Deduplication

* Same `dicom_study_uid` may be processed multiple times

---

### 3. Non-Deterministic Order

* Uses `as_completed()`
* Order depends on completion time

---

### 4. Permission Mismatch

* Uses:

  ```
  can_write_service_request
  ```
* Even though API is read-only

---

## 10. Production Improvements

### 1. Filter None Results

```python
result = future.result()
if result:
    results.append(result)
```

---

### 2. Deduplicate Study UIDs

Before submission:

```python
unique_uids = set(...)
```

---

### 3. Add Ordering

Sort results by:

* study_date

---

### 4. Add Error Handling

```python
try:
    result = future.result()
except Exception:
    continue
```

---

### 5. Add Timeout to Requests

* Prevent hanging threads

---

### 6. Configurable Thread Count

* Move `max_workers` to settings

---

### 7. Logging

* Track failures from DICOM server

---

## 11. Summary

This API:

* Uses **ServiceRequest as entry point**
* Relies on **RadiologyServiceRequest mapping**
* Fetches DICOM metadata dynamically
* Uses **parallel execution + as_completed**
* Returns **unfiltered, unordered results**

It acts as a bridge between:

* Clinical workflow (ServiceRequest)
* Imaging system (DICOM server)

```
```
