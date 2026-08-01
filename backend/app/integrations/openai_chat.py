import base64
import hashlib
from collections.abc import AsyncIterator, Sequence
from dataclasses import dataclass

from openai import (
    APIConnectionError,
    APIStatusError,
    APITimeoutError,
    AsyncOpenAI,
    AuthenticationError,
    BadRequestError,
    PermissionDeniedError,
    RateLimitError,
)

from app.core.config import Settings
from app.core.errors import AppError


@dataclass(frozen=True, slots=True)
class ChatInputMessage:
    role: str
    content: str


@dataclass(frozen=True, slots=True)
class ChatCompletion:
    content: str
    response_id: str
    model_name: str
    input_tokens: int
    output_tokens: int


@dataclass(frozen=True, slots=True)
class ChatStreamEvent:
    delta: str | None = None
    completion: ChatCompletion | None = None


class OpenAIChatPermanentError(Exception):
    def __init__(self, failure_code: str) -> None:
        super().__init__(failure_code)
        self.failure_code = failure_code


class OpenAIChatProvider:
    provider_name = "OPENAI"

    def __init__(self, settings: Settings, client: AsyncOpenAI | None = None) -> None:
        self._api_key = settings.openai_api_key
        self.model_name = settings.openai_chat_model
        self._max_output_tokens = settings.openai_chat_max_output_tokens
        self._client = client
        if client is None and self._api_key:
            self._client = AsyncOpenAI(
                api_key=self._api_key,
                timeout=settings.openai_timeout_seconds,
                max_retries=0,
            )

    def ensure_configured(self) -> None:
        if self._client is None:
            raise AppError(
                code="AI_PROVIDER_NOT_CONFIGURED",
                message="AI 채팅 설정이 완료되지 않았습니다.",
                status_code=503,
            )

    async def stream_reply(
        self,
        *,
        instructions: str,
        messages: Sequence[ChatInputMessage],
        safety_user_id: str,
    ) -> AsyncIterator[ChatStreamEvent]:
        self.ensure_configured()
        assert self._client is not None
        try:
            stream = await self._client.responses.create(
                model=self.model_name,
                instructions=instructions,
                input=_text_input(messages),
                max_output_tokens=self._max_output_tokens,
                reasoning={"effort": "minimal"},
                safety_identifier=_safety_identifier(safety_user_id),
                store=False,
                stream=True,
                text={"verbosity": "low"},
            )
            async for event in stream:
                if event.type == "response.output_text.delta":
                    yield ChatStreamEvent(delta=event.delta)
                elif event.type == "response.completed":
                    response = event.response
                    usage = response.usage
                    yield ChatStreamEvent(
                        completion=ChatCompletion(
                            content=response.output_text,
                            response_id=response.id,
                            model_name=response.model,
                            input_tokens=usage.input_tokens if usage else 0,
                            output_tokens=usage.output_tokens if usage else 0,
                        )
                    )
                    return
            raise AppError(
                code="AI_PROVIDER_INCOMPLETE_RESPONSE",
                message="AI 응답이 완료되지 않았습니다.",
                status_code=503,
            )
        except Exception as exc:
            raise _map_provider_error(exc) from exc

    async def reply_with_image(
        self,
        *,
        instructions: str,
        messages: Sequence[ChatInputMessage],
        image: bytes,
        content_type: str,
        caption: str,
        safety_user_id: str,
    ) -> ChatCompletion:
        self.ensure_configured()
        assert self._client is not None
        inputs = _text_input(messages)
        inputs.append(
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": caption or "이 사진을 살펴봐 주세요."},
                    {
                        "type": "input_image",
                        "image_url": (
                            f"data:{content_type};base64,{base64.b64encode(image).decode('ascii')}"
                        ),
                        "detail": "low",
                    },
                ],
            }
        )
        try:
            response = await self._client.responses.create(
                model=self.model_name,
                instructions=instructions,
                input=inputs,
                max_output_tokens=self._max_output_tokens,
                reasoning={"effort": "minimal"},
                safety_identifier=_safety_identifier(safety_user_id),
                store=False,
                text={"verbosity": "low"},
            )
        except Exception as exc:
            raise _map_provider_error(exc) from exc
        usage = response.usage
        return ChatCompletion(
            content=response.output_text,
            response_id=response.id,
            model_name=response.model,
            input_tokens=usage.input_tokens if usage else 0,
            output_tokens=usage.output_tokens if usage else 0,
        )

    async def summarize(
        self,
        *,
        current_summary: str | None,
        messages: Sequence[ChatInputMessage],
        safety_user_id: str,
    ) -> str:
        self.ensure_configured()
        assert self._client is not None
        prompt = "기존 요약:\n" + (current_summary or "없음") + "\n\n추가 대화:\n"
        prompt += "\n".join(f"{message.role}: {message.content}" for message in messages)
        try:
            response = await self._client.responses.create(
                model=self.model_name,
                instructions=(
                    "식물 관리 상담 대화를 한국어로 짧게 누적 요약하세요. "
                    "사용자가 말한 사실, 이미 수행한 관리, 미해결 질문만 보존하세요."
                ),
                input=prompt,
                max_output_tokens=500,
                reasoning={"effort": "minimal"},
                safety_identifier=_safety_identifier(safety_user_id),
                store=False,
                text={"verbosity": "low"},
            )
        except Exception as exc:
            raise _map_provider_error(exc) from exc
        return response.output_text.strip()

    async def close(self) -> None:
        if self._client is not None:
            await self._client.close()


def _text_input(messages: Sequence[ChatInputMessage]) -> list[dict]:
    return [{"role": message.role.lower(), "content": message.content} for message in messages]


def _safety_identifier(user_id: str) -> str:
    return hashlib.sha256(user_id.encode()).hexdigest()


def _map_provider_error(exc: Exception) -> Exception:
    if isinstance(exc, OpenAIChatPermanentError):
        return exc
    if isinstance(exc, (AuthenticationError, PermissionDeniedError)):
        return OpenAIChatPermanentError("AI_PROVIDER_AUTH_FAILED")
    if isinstance(exc, BadRequestError):
        return OpenAIChatPermanentError("AI_PROVIDER_REJECTED_INPUT")
    if isinstance(exc, (RateLimitError, APITimeoutError, APIConnectionError)):
        return AppError(
            code="AI_PROVIDER_UNAVAILABLE",
            message="AI 응답을 생성할 수 없습니다.",
            status_code=503,
        )
    if isinstance(exc, APIStatusError):
        if exc.status_code >= 500:
            return AppError(
                code="AI_PROVIDER_UNAVAILABLE",
                message="AI 응답을 생성할 수 없습니다.",
                status_code=503,
            )
        return OpenAIChatPermanentError("AI_PROVIDER_REJECTED_INPUT")
    return AppError(
        code="AI_PROVIDER_UNAVAILABLE",
        message="AI 응답을 생성할 수 없습니다.",
        status_code=503,
    )
