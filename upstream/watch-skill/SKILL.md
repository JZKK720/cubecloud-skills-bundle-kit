---
name: watch-skill
description: Video intelligence skill — watch, remember, and verify video content. Use when analyzing video files, extracting frames, searching video moments, transcribing audio, detecting objects or scenes, or building video-aware agent workflows. MCP server via `watch-skill serve`.
---

# Watch Skill

Video intelligence for AI agents — watch video content, extract meaningful
moments, remember what was seen, and verify claims against visual evidence.

## When to use

- Analyzing video files for content, objects, or scenes
- Extracting key frames or moments from video
- Transcribing speech from video audio
- Searching for specific moments across video libraries
- Building video-aware agent workflows (monitoring, review, verification)
- Verifying claims against video evidence

## Core capabilities

### Watch (ingest)
- Load video from local files, URLs, or streams
- Extract frames at specified intervals or on scene changes
- Capture metadata (duration, resolution, codec, fps)

### Remember (index)
- Build searchable indexes of video moments
- Store frame embeddings for semantic search
- Track timestamps and scene boundaries

### Verify (query)
- Search for specific objects, people, or scenes
- Compare frames across videos
- Validate claims against visual evidence
- Generate timestamped evidence clips

## MCP integration

Start the MCP server:
```bash
watch-skill serve          # stdio transport (default)
watch-skill serve --http   # Streamable HTTP on port 8747
```

The MCP server exposes tools for video ingestion, frame extraction, semantic
search, and moment verification.

## Related skills

- **videodb**: Full video/audio pipeline (ingest, index, edit, generate)
- **video-editing**: AI-assisted video editing and production
- **ui-demo**: Record polished UI demo videos
- **fal-ai-media**: AI media generation (image, video, audio)
- **remotion-video-creation**: Programmatic video creation in React
