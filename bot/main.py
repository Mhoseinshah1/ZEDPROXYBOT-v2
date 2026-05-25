import asyncio
from aiogram import Bot, Dispatcher
from aiogram.filters import CommandStart
from aiogram.types import Message, ReplyKeyboardMarkup, KeyboardButton

from app.core.config import settings


def build_main_menu(is_admin: bool = False) -> ReplyKeyboardMarkup:
    buttons = [
        [KeyboardButton(text="🔐 خرید اشتراک"), KeyboardButton(text="🏦 کیف پول + شارژ")],
        [KeyboardButton(text="اشتراک رایگان {تست}"), KeyboardButton(text="♻️ تمدید سرویس")],
        [KeyboardButton(text="🛍 سرویس‌های من"), KeyboardButton(text="📚 آموزش")],
        [KeyboardButton(text="👥 زیر مجموعه گیری"), KeyboardButton(text="🎲 گردونه شانس")],
        [KeyboardButton(text="درخواست نمایندگی")],
    ]
    if is_admin:
        buttons.append([KeyboardButton(text="🛠 پنل ادمین")])
    return ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True)


def is_owner(telegram_id: int) -> bool:
    return telegram_id == settings.MAIN_ADMIN_ID


def is_admin(telegram_id: int) -> bool:
    return is_owner(telegram_id)


async def ensure_main_admin(_: Message) -> None:
    # Placeholder for DB-backed upsert of owner admin record.
    return None


async def main() -> None:
    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher()

    @dp.message(CommandStart())
    async def start_handler(message: Message) -> None:
        await ensure_main_admin(message)
        admin = is_admin(message.from_user.id if message.from_user else 0)
        await message.answer("به ربات فروش VPN خوش آمدید.", reply_markup=build_main_menu(admin))

    if not settings.USE_WEBHOOK:
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    else:
        raise RuntimeError("Webhook mode is not enabled in this baseline build. Set USE_WEBHOOK=false.")


if __name__ == "__main__":
    asyncio.run(main())
